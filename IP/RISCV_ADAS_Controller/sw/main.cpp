extern "C" void* memcpy(void* dest, const void* src, unsigned int n) {
    char* d = (char*)dest;
    const char* s = (const char*)src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}
#include <stdint.h>
#include <stdbool.h>

// =============================================================================
// NPU and ADAS Hardware Memory Map
// =============================================================================
#define NPU_CSR_BASE      0x80000000
#define CANDIDATE_BRAM    0xC0000000

// NPU CSR Offsets (Matched with axi4_lite_slave.v)
#define REG_CTRL          0x00
#define REG_STATUS        0x04
#define REG_THRESH_LOGIT  0x84
#define REG_MAX_CANDS     0x88
#define REG_CLEAR_FRAME   0x8C
#define REG_SCALE_ID      0x90

// =============================================================================
// Data Structures
// =============================================================================
typedef struct __attribute__((packed)) {
    uint16_t flags;
    uint16_t scale_id;
    uint16_t x1;
    uint16_t y1;
    uint16_t x2;
    uint16_t y2;
    int16_t  score;
    uint16_t class_id;
} BoundingBox;

#define MAX_BOXES 100

// Enums for Class IDs (Expandable for 200 classes)
enum RoadClasses {
    CLASS_PEDESTRIAN = 0,
    CLASS_BICYCLE    = 1,
    CLASS_CAR        = 2,
    CLASS_MOTORCYCLE = 3,
    CLASS_BUS        = 5,
    CLASS_TRAIN      = 6,
    CLASS_TRUCK      = 7,
    CLASS_TRAFFIC_LIGHT = 9,
    CLASS_STOP_SIGN  = 11
};

// =============================================================================
// Helper Functions
// =============================================================================
static inline void reg_write32(uint32_t addr, uint32_t val) {
    *((volatile uint32_t*)addr) = val;
}

static inline uint32_t reg_read32(uint32_t addr) {
    return *((volatile uint32_t*)addr);
}

static inline uint16_t min16(uint16_t a, uint16_t b) { return a < b ? a : b; }
static inline uint16_t max16(uint16_t a, uint16_t b) { return a > b ? a : b; }

// =============================================================================
// NMS & IoU Math
// =============================================================================
bool check_iou(const BoundingBox* a, const BoundingBox* b, uint32_t t_num, uint32_t t_den) {
    uint16_t ix1 = max16(a->x1, b->x1);
    uint16_t iy1 = max16(a->y1, b->y1);
    uint16_t ix2 = min16(a->x2, b->x2);
    uint16_t iy2 = min16(a->y2, b->y2);

    if (ix2 <= ix1 || iy2 <= iy1) {
        return false; // No overlap
    }

    uint32_t i_area = (uint32_t)(ix2 - ix1) * (uint32_t)(iy2 - iy1);
    uint32_t a_area = (uint32_t)(a->x2 - a->x1) * (uint32_t)(a->y2 - a->y1);
    uint32_t b_area = (uint32_t)(b->x2 - b->x1) * (uint32_t)(b->y2 - b->y1);
    uint32_t u_area = a_area + b_area - i_area;

    return (i_area * t_den) > (u_area * t_num);
}

void sort_boxes_by_score(BoundingBox* boxes, int count) {
    for (int i = 0; i < count - 1; i++) {
        for (int j = 0; j < count - i - 1; j++) {
            if (boxes[j].score < boxes[j+1].score) {
                BoundingBox temp = boxes[j];
                boxes[j] = boxes[j+1];
                boxes[j+1] = temp;
            }
        }
    }
}

// =============================================================================
// Main Control Loop
// =============================================================================
int main() {
    // Configure NPU Constants
    reg_write32(NPU_CSR_BASE + REG_MAX_CANDS, MAX_BOXES);
    reg_write32(NPU_CSR_BASE + REG_THRESH_LOGIT, 0); // Logit 0 = 50% confidence
    reg_write32(NPU_CSR_BASE + REG_SCALE_ID, 1);
    
    BoundingBox local_boxes[MAX_BOXES];
    bool suppressed[MAX_BOXES];

    while (1) {
        // Clear BRAM Frame
        reg_write32(NPU_CSR_BASE + REG_CLEAR_FRAME, 1);
        reg_write32(NPU_CSR_BASE + REG_CLEAR_FRAME, 0);

        // Start NPU and wait for frame
        reg_write32(NPU_CSR_BASE + REG_CTRL, 1);
        while ((reg_read32(NPU_CSR_BASE + REG_STATUS) & 0x01) != 0) {
            // Spinwait for Busy bit to clear
        }
        
        // Fetch 128-bit structs from BRAM directly to local memory
        uint32_t cand_count = MAX_BOXES; // Simplified for this run
        volatile uint32_t* bram_ptr = (volatile uint32_t*)CANDIDATE_BRAM;
        
        for (uint32_t i = 0; i < cand_count; i++) {
            uint32_t w0 = bram_ptr[i*4 + 0];
            uint32_t w1 = bram_ptr[i*4 + 1];
            uint32_t w2 = bram_ptr[i*4 + 2];
            uint32_t w3 = bram_ptr[i*4 + 3];
            
            // Break early if we hit empty records (Assuming flags==0 means empty)
            if (w0 == 0 && w1 == 0 && w2 == 0 && w3 == 0) {
                cand_count = i;
                break;
            }
            
            local_boxes[i].flags    = w0 & 0xFFFF;
            local_boxes[i].scale_id = w0 >> 16;
            local_boxes[i].x1       = w1 & 0xFFFF;
            local_boxes[i].y1       = w1 >> 16;
            local_boxes[i].x2       = w2 & 0xFFFF;
            local_boxes[i].y2       = w2 >> 16;
            local_boxes[i].score    = w3 & 0xFFFF;
            local_boxes[i].class_id = w3 >> 16;
            
            suppressed[i] = false;
        }

        // NMS Pipeline
        sort_boxes_by_score(local_boxes, cand_count);

        for (uint32_t i = 0; i < cand_count; i++) {
            if (suppressed[i]) continue;
            for (uint32_t j = i + 1; j < cand_count; j++) {
                if (suppressed[j]) continue;
                
                if (local_boxes[i].class_id == local_boxes[j].class_id) {
                    if (check_iou(&local_boxes[i], &local_boxes[j], 9, 20)) {
                        suppressed[j] = true;
                    }
                }
            }
        }
        
        // Next frame
    }

    return 0;
}

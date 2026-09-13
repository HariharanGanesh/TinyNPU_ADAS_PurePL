#include <stdint.h>
#include <stdbool.h>

// =============================================================================
// NPU and ADAS Hardware Memory Map
// =============================================================================
#define NPU_CSR_BASE      0x40000000
#define ADAS_REG_BASE     0x42000000
#define CANDIDATE_BRAM    0x44000000

// NPU CSR Offsets
#define REG_CTRL          0x00
#define REG_STATUS        0x04
#define REG_CAND_COUNT    0x08
#define REG_THRESH_LOGIT  0x0C
#define REG_MAX_CANDS     0x10

// ADAS Register Offsets
#define REG_DETECTIONS    0x00
#define REG_CONFIGS       0x04
#define REG_WDT_PET       0x08

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

#define MAX_BOXES 128

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

// Integer absolute value helper
static inline int32_t abs_val(int32_t x) {
    return x < 0 ? -x : x;
}

// Max/Min helpers
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

    // IoU > (t_num / t_den)  =>  (i_area * t_den) > (u_area * t_num)
    return (i_area * t_den) > (u_area * t_num);
}

void sort_boxes_by_score(BoundingBox* boxes, int count) {
    // Simple Bubble Sort (efficient enough for N < 128 sparse boxes)
    for (int i = 0; i < count - 1; i++) {
        for (int j = 0; j < count - i - 1; j++) {
            if (boxes[j].score < boxes[j+1].score) {
                // Manual copy to avoid implicit memcpy missing in freestanding env
                BoundingBox temp;
                temp.flags = boxes[j].flags; temp.scale_id = boxes[j].scale_id;
                temp.x1 = boxes[j].x1; temp.y1 = boxes[j].y1;
                temp.x2 = boxes[j].x2; temp.y2 = boxes[j].y2;
                temp.score = boxes[j].score; temp.class_id = boxes[j].class_id;

                boxes[j].flags = boxes[j+1].flags; boxes[j].scale_id = boxes[j+1].scale_id;
                boxes[j].x1 = boxes[j+1].x1; boxes[j].y1 = boxes[j+1].y1;
                boxes[j].x2 = boxes[j+1].x2; boxes[j].y2 = boxes[j+1].y2;
                boxes[j].score = boxes[j+1].score; boxes[j].class_id = boxes[j+1].class_id;

                boxes[j+1].flags = temp.flags; boxes[j+1].scale_id = temp.scale_id;
                boxes[j+1].x1 = temp.x1; boxes[j+1].y1 = temp.y1;
                boxes[j+1].x2 = temp.x2; boxes[j+1].y2 = temp.y2;
                boxes[j+1].score = temp.score; boxes[j+1].class_id = temp.class_id;
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
    
    BoundingBox local_boxes[MAX_BOXES];
    bool suppressed[MAX_BOXES];

    while (1) {
        // 1. Pet Watchdog
        reg_write32(ADAS_REG_BASE + REG_WDT_PET, 0x5A);

        // 2. Start NPU and wait for frame
        reg_write32(NPU_CSR_BASE + REG_CTRL, 1);
        while ((reg_read32(NPU_CSR_BASE + REG_STATUS) & 0x02) == 0) {
            // Spinwait for Done bit
        }
        
        // 3. Read sparse candidate count
        uint32_t cand_count = reg_read32(NPU_CSR_BASE + REG_CAND_COUNT);
        if (cand_count > MAX_BOXES) cand_count = MAX_BOXES;

        // 4. Fetch 128-bit structs from BRAM directly to local memory
        volatile uint32_t* bram_ptr = (volatile uint32_t*)CANDIDATE_BRAM;
        for (uint32_t i = 0; i < cand_count; i++) {
            uint32_t w0 = bram_ptr[i*4 + 0];
            uint32_t w1 = bram_ptr[i*4 + 1];
            uint32_t w2 = bram_ptr[i*4 + 2];
            uint32_t w3 = bram_ptr[i*4 + 3];
            
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

        // 5. NMS Pipeline
        sort_boxes_by_score(local_boxes, cand_count);

        for (uint32_t i = 0; i < cand_count; i++) {
            if (suppressed[i]) continue;
            
            for (uint32_t j = i + 1; j < cand_count; j++) {
                if (suppressed[j]) continue;
                
                // Class-aware NMS: Only suppress if they are the same class
                if (local_boxes[i].class_id == local_boxes[j].class_id) {
                    // 0.45 IoU Threshold -> 9 / 20
                    if (check_iou(&local_boxes[i], &local_boxes[j], 9, 20)) {
                        suppressed[j] = true;
                    }
                }
            }
        }

        // 6. ADAS Actuator Routing
        uint32_t adas_flags = 0;
        for (uint32_t i = 0; i < cand_count; i++) {
            if (!suppressed[i]) {
                switch(local_boxes[i].class_id) {
                    case CLASS_PEDESTRIAN: adas_flags |= 0x01; break;
                    case CLASS_CAR:
                    case CLASS_TRUCK:
                    case CLASS_BUS:        adas_flags |= 0x02; break; // Obstacle
                    case CLASS_STOP_SIGN:  adas_flags |= 0x08; break; // Sign logic
                }
            }
        }
        
        // Write combined flags to hardware safety unit
        reg_write32(ADAS_REG_BASE + REG_DETECTIONS, adas_flags);
        
        // Reset NPU for next frame
        reg_write32(NPU_CSR_BASE + REG_CTRL, 2); 
    }

    return 0;
}

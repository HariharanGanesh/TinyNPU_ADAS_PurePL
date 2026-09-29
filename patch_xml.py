import sys
import xml.etree.ElementTree as ET

xml_file = "IP/TinyNPU200/component.xml"
tree = ET.parse(xml_file)
root = tree.getroot()

namespace = {'spirit': 'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009',
             'xilinx': 'http://www.xilinx.com',
             'xsi': 'http://www.w3.org/2001/XMLSchema-instance'}

ET.register_namespace('spirit', namespace['spirit'])
ET.register_namespace('xilinx', namespace['xilinx'])
ET.register_namespace('xsi', namespace['xsi'])

missing_files = ["src/dw_line_buffer.v", "src/pipelined_mult_8x8.v"]

# Find fileSets
for fileset in root.findall('.//spirit:fileSet', namespace):
    name_node = fileset.find('spirit:name', namespace)
    if name_node is not None and name_node.text in ['xilinx_anylanguagesynthesis_view_fileset', 'xilinx_anylanguagebehavioralsimulation_view_fileset']:
        # Check if already present
        existing_files = [f.find('spirit:name', namespace).text for f in fileset.findall('spirit:file', namespace)]
        
        for mf in missing_files:
            if mf not in existing_files:
                file_elem = ET.SubElement(fileset, '{http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009}file')
                name_elem = ET.SubElement(file_elem, '{http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009}name')
                name_elem.text = mf
                fileType_elem = ET.SubElement(file_elem, '{http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009}fileType')
                fileType_elem.text = 'verilogSource'
                
                print(f"Added {mf} to {name_node.text}")

tree.write(xml_file, xml_declaration=True, encoding='utf-8')
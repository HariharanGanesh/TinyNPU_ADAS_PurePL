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

for revision in root.findall('.//xilinx:coreRevision', namespace):
    rev_int = int(revision.text)
    revision.text = str(rev_int + 1)
    print(f"Bumped coreRevision to {revision.text}")

tree.write(xml_file, xml_declaration=True, encoding='utf-8')
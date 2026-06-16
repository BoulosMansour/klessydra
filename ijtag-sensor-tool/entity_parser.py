import re

def entityParser(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        vhdlCode = f.read()

    # 1. Get Entity Name
    entityMatch = re.search(r'(?i)entity\s+(\w+)\s+is', vhdlCode)
    entityName = entityMatch.group(1) if entityMatch else "UNKNOWN_ENTITY"

    # 2. Find the port block using parenthesis counting
    portStartMatch = re.search(r'(?i)\bport\s*\(', vhdlCode)
    startIdx = portStartMatch.end() - 1
    parenCount = 0
    endIdx = -1

    for i in range(startIdx, len(vhdlCode)):
        if vhdlCode[i] == '(':
            parenCount += 1
        elif vhdlCode[i] == ')':
            parenCount -= 1
            if parenCount == 0:
                endIdx = i
                break

    portBlock = vhdlCode[startIdx + 1 : endIdx]

    # 3. CLEAN UP THE TEXT
    # Remove all VHDL comments
    portBlock = re.sub(r'--.*', '', portBlock)
    # Flatten everything into a single line to prevent regex newline errors
    portBlock = portBlock.replace('\n', ' ').replace('\r', ' ')

    extractedPorts = []
    extractedGenerics = []

    # 4. Extract the ports
    for portDeclaration in portBlock.split(';'):
        portDeclaration = portDeclaration.strip()
        if not portDeclaration:
            continue

        if ':' in portDeclaration:
            namesPart, typePart = portDeclaration.split(':', 1)

            # Find the mode (in/out/inout) and the rest is the type
            typeMatch = re.match(r'(?i)^\s*(in|out|inout|buffer)\s+(.*)', typePart)
            if typeMatch:
                mode = typeMatch.group(1).lower()
                # Split off any default assignment (:= '0'). The default must be
                # preserved on the component declaration so that instantiations
                # may legally leave the port 'open' (DC enforces this).
                typeAndDefault = typeMatch.group(2).strip()
                if ':=' in typeAndDefault:
                    cleanType, default = typeAndDefault.split(':=', 1)
                    cleanType = cleanType.strip()
                    default = default.strip()
                else:
                    cleanType = typeAndDefault
                    default = None

                # Handle multiple ports (clk, rst : in std_logic)
                portNames = [n.strip() for n in namesPart.split(',')]

                for name in portNames:
                    extractedPorts.append({
                        "name": name,
                        "mode": mode,
                        "data_type": cleanType,
                        "default": default
                    })

    # 5. get the generic block
    genericMatch = re.search(r'(?i)generic\s*\((.*?)\)\s*;', vhdlCode, re.DOTALL)
    if genericMatch:
        genericBlock = genericMatch.group(1)
        genericBlock = re.sub(r'--.*', '', genericBlock).replace('\n', ' ').replace('\r', ' ')

        for genericDeclaration in genericBlock.split(';'):
            genericDeclaration = genericDeclaration.strip()
            if not genericDeclaration:
                continue

            if ':' in genericDeclaration:
                namePart, typePart = genericDeclaration.split(':', 1)
                name = namePart.strip()
                cleanType = typePart.split(':=')[0].strip()  # Remove default assignment
                extractedGenerics.append({
                    "name": name,
                    "data_type": cleanType
                })

    return entityName, extractedPorts, extractedGenerics

def generateComponentVHDL(generics, ports, entityName):
    vhdl = f"component {entityName} is\n"

    if generics:
        vhdl += "\tgeneric (\n"
        for i, g in enumerate(generics):
            sep = ";" if i < len(generics) - 1 else ""
            vhdl += f"\t\t{g['name']} : {g['data_type']}{sep}\n"
        vhdl += "\t);\n"

    if ports:
        vhdl += "\tport (\n"
        for i, p in enumerate(ports):
            sep = ";" if i < len(ports) - 1 else ""
            defaultStr = f" := {p['default']}" if p.get('default') else ""
            vhdl += f"\t\t{p['name']} : {p['mode']} {p['data_type']}{defaultStr}{sep}\n"
        vhdl += "\t);\n"

    vhdl += f"end component {entityName};\n"

    return vhdl

def generateInstanceMapVHDL(instanceName, entityName, genericMapping, portMapping):
    vhdl = f"{instanceName} : {entityName}\n"

    if genericMapping:
        items = list(genericMapping.items())
        vhdl += "\tgeneric map (\n"
        for i, (key, value) in enumerate(items):
            sep = "," if i < len(items) - 1 else ""
            vhdl += f"\t\t{key} => {value}{sep}\n"
        vhdl += "\t)\n"  # no semicolon here — port map follows

    if portMapping:
        items = list(portMapping.items())
        vhdl += "\tport map (\n"
        for i, (key, value) in enumerate(items):
            sep = "," if i < len(items) - 1 else ""
            vhdl += f"\t\t{key} => {value}{sep}\n"
        vhdl += "\t);\n"

    return vhdl

def checkEntityName(filepath, expectedName):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        vhdlCode = f.read()

    entityMatch = re.search(r'(?i)entity\s+(\w+)\s+is', vhdlCode)
    entityName = entityMatch.group(1) if entityMatch else None

    return entityName == expectedName

def fetchDeclaredComponents(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        vhdlCode = f.read()

    componentNames = re.findall(r'(?i)component\s+(\w+)\s+is', vhdlCode)

    return componentNames


# ==========================================
# Testing the Edge Cases!
# ==========================================
if __name__ == "__main__":

    # Run our robust parser
    entityName, ports, generics = entityParser("nasty_sensor.vhd")

    print(generateComponentVHDL(generics, ports, entityName))
    print(checkEntityName("nasty_sensor.vhd", "advanced_thermal_sensor"))
    print(f"Declared components: {fetchDeclaredComponents('nasty_sensor.vhd')}")

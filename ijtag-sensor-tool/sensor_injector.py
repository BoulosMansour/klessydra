import json
import entity_parser
import glob
import os
import re
import logging

PRAGMA_DECLARATION = "-- SENSOR-DECLARATION: "
PRAGMA_INSTANCIATION = "-- SENSOR-INSTANTIATION: "

topLevelEntity = ""
workingDirectory = ""
sensorsDirectory = ""
customComponents = {}
sensors = {}
instances = {}
configurations = {}
packageFiles = []
cellLibraryFiles = []
designId = "rtl1"
clockPort = "clk_i"
clockPeriod = "10ns"
ijtagPorts = {}
synthesisConfig = {}
designLevel = "physical_block"


def getConfig():

    global topLevelEntity, workingDirectory, sensorsDirectory, customComponents, sensors, instances
    global configurations, packageFiles, cellLibraryFiles, designId, clockPort, clockPeriod
    global ijtagPorts, synthesisConfig, designLevel
    with open('config.json', 'r') as f:
        config = json.load(f)

    topLevelEntity = config.get("topLevelEntity", "")
    workingDirectory = config.get("workingDirectory", "")
    sensorsDirectory = config.get("sensorsDirectory", "")
    customComponents = config.get("customComponents", {})
    sensors = config.get("sensors", {})
    instances = config.get("instances", {})
    configurations = config.get("configurations", {})
    packageFiles = config.get("packageFiles", [])
    cellLibraryFiles = config.get("cellLibraryFiles", [])
    designId = config.get("designId", "rtl1")
    clockPort = config.get("clockPort", "clk_i")
    clockPeriod = config.get("clockPeriod", "10ns")
    ijtagPorts = config.get("ijtagPorts", {})
    synthesisConfig = config.get("synthesis", {})
    designLevel = config.get("designLevel", "physical_block")


def getInstantiatedSensors(activeInstances):
    """Return the set of sensor (type) names actually instantiated in this config."""
    names = set()
    for inst in activeInstances.values():
        sn = inst.get("sensor_name", "")
        if sn:
            names.add(sn)
    return names


def scanAndInjectSensors(activeInstances, modifiedDir):
    """
    Scan all VHDL files in the working directory (excluding the generated out/
    tree), parse them for sensor pragmas, and inject the component declarations
    and instance mappings for the instances ACTIVE in this configuration.

    An instantiation pragma whose instance is not part of the current
    configuration is left untouched (it stays a harmless VHDL comment), so the
    same source files drive every sensor-count configuration without edits.
    """
    outputDir = os.path.join(workingDirectory, "out")

    # Glob all VHD files recursively, then exclude our own generated output tree
    # (out/ and any legacy top-level modified/) so re-running the tool never
    # picks up previously generated files.
    outputDirNorm = os.path.normpath(outputDir) + os.sep
    legacyModifiedNorm = os.path.normpath(os.path.join(workingDirectory, "modified")) + os.sep
    allVHDLFiles = [
        f for f in glob.glob(os.path.join(workingDirectory, "**/*.vhd"), recursive=True)
        if not os.path.normpath(f).startswith(outputDirNorm)
        and not os.path.normpath(f).startswith(legacyModifiedNorm)
    ]

    # Create or clean this configuration's modified directory
    if not os.path.exists(modifiedDir):
        os.makedirs(modifiedDir)
    else:
        for file in os.listdir(modifiedDir):
            os.remove(os.path.join(modifiedDir, file))

    logging.info(f"Found {len(allVHDLFiles)} VHDL files to scan in '{workingDirectory}'")

    for vhdlFile in allVHDLFiles:
        with open(vhdlFile, 'r', encoding='utf-8', errors='replace') as f:
            vhdlContent = f.read()

        if PRAGMA_DECLARATION in vhdlContent:
            logging.info(f"Processing file with sensor pragmas: '{vhdlFile}'")

            # find all pragma declarations in the file and extract the sensor entity name
            declarations = re.findall(rf"{PRAGMA_DECLARATION}\s*(\w+)", vhdlContent)

            # find all pragma instantiations in the file and extract the instance name
            instantiations = re.findall(rf"{PRAGMA_INSTANCIATION}\s*(\w+)", vhdlContent)

            logging.info(f"  Declarations found: {declarations}")
            logging.info(f"  Instantiations found: {instantiations}")

            for instanceName in instantiations:
                if instanceName not in instances:
                    logging.error(f"Instance '{instanceName}' in file '{vhdlFile}' does not match any sensor in config.json")
                    continue
                if instanceName not in activeInstances:
                    # Not part of this configuration -- leave the pragma as a comment.
                    logging.info(f"  Instance '{instanceName}' not in current configuration; leaving pragma unfilled")
                    continue
                sensorInfo = activeInstances[instanceName]

                sensorPath = sensors.get(sensorInfo.get("sensor_name", ""), {}).get("vhdl_file_path", "")
                if not sensorPath:
                    logging.error(f"Sensor '{sensorInfo.get('sensor_name', '')}' for instance '{instanceName}' in file '{vhdlFile}' does not have a 'vhdl_file_path' defined in config.json")
                    continue
                sensorEntity, _, _ = entity_parser.entityParser(os.path.join(sensorsDirectory, sensorPath))
                if not sensorEntity:
                    logging.error(f"Instance '{instanceName}' in file '{vhdlFile}' does not have a 'component_name' defined in config.json")
                    continue
                if sensorEntity not in declarations:
                    logging.error(f"Instance '{instanceName}' in file '{vhdlFile}' references entity '{sensorEntity}' which does not have a component declaration pragma in the same file")
                    continue

                # support both legacy and current keys in config
                configGenerics = sensorInfo.get("generic_maps", sensorInfo.get("generics", {}))
                configPorts = sensorInfo.get("port_maps", sensorInfo.get("ports", {}))

                # load sensor VHDL and parse ports/generics
                sensorVhdlPath = os.path.join(sensorsDirectory, sensorPath)
                sensorEntityName, sensorPortsList, sensorGenericsList = entity_parser.entityParser(sensorVhdlPath)
                if not sensorPortsList and not sensorGenericsList:
                    logging.error(f"Entity '{sensorEntity}' for instance '{instanceName}' does not have any ports or generics defined in its VHDL file")
                    continue

                if configGenerics and not sensorGenericsList:
                    logging.warning(f"Instance '{instanceName}' in file '{vhdlFile}' has generics defined in config.json but the entity '{sensorEntity}' does not have any generics defined in its VHDL file")

                if configPorts and not sensorPortsList:
                    logging.error(f"Instance '{instanceName}' in file '{vhdlFile}' has ports defined in config.json but the entity '{sensorEntity}' does not have any ports defined in its VHDL file")
                    continue

                # build set of declared port names from the parsed entity
                entityPortNames = {p['name'] for p in sensorPortsList}

                # validate config port names -- report missing names
                badPorts = []
                for cfgPort in configPorts.keys():
                    if cfgPort not in entityPortNames:
                        badPorts.append(cfgPort)
                if badPorts:
                    logging.error(f"Instance '{instanceName}' in file '{vhdlFile}' has ports in config.json that are not present on entity '{sensorEntity}': {badPorts}")
                    continue

                # default any missing entity ports to 'open' mapping
                for p in entityPortNames:
                    if p not in configPorts:
                        configPorts[p] = "open"
                        logging.warning(f"Port '{p}' of instance '{instanceName}' in file '{vhdlFile}' is not defined in config.json. Defaulting to 'open'")

                componentDeclarationContent = entity_parser.generateComponentVHDL(sensorGenericsList, sensorPortsList, sensorEntity)
                instanceMappingContent = entity_parser.generateInstanceMapVHDL(instanceName, sensorEntity, configGenerics, configPorts)

                # Replace the declaration pragma (keyed by entity name, not instance name).
                # Only replace on first encounter — subsequent instances of the same sensor type
                # find the pragma already replaced and skip silently.
                declarationPragma = f"{PRAGMA_DECLARATION}{sensorEntity}"
                if declarationPragma in vhdlContent:
                    vhdlContent = vhdlContent.replace(declarationPragma, componentDeclarationContent)
                    logging.info(f"  Replaced declaration pragma for entity '{sensorEntity}'")

                # Replace the instantiation pragma (keyed by instance name, unique per instance)
                instantiationPragma = f"{PRAGMA_INSTANCIATION}{instanceName}"
                if instantiationPragma in vhdlContent:
                    vhdlContent = vhdlContent.replace(instantiationPragma, instanceMappingContent)
                    logging.info(f"  Replaced instantiation pragma for instance '{instanceName}'")
                else:
                    logging.error(f"Could not find instantiation pragma '{instantiationPragma}' in '{vhdlFile}'")

        # Write the (possibly modified) file into the modified directory
        newFileName = os.path.join(modifiedDir, f"modified_{os.path.basename(vhdlFile)}")
        with open(newFileName, 'w', encoding='utf-8') as f:
            f.write(vhdlContent)
        logging.info(f"Written modified file: '{newFileName}'")


def generateICLExtractionScript(activeInstances, outputDir):
    """
    PHASE 1: generate, per instantiated sensor, a Tessent script that reads only
    that sensor, types its IJTAG ports, and lets Tessent EXTRACT the instrument's
    ICL (<outputDir>/icl/<sensor>.icl). The main insertion flow then read_icl's
    these so Tessent recognises the sensors as IJTAG instruments. The sensor RTL
    itself is never modified -- only its IJTAG port roles are declared here.

    Returns {sensorName: iclPath} for the ICLs that will be produced.
    """
    os.makedirs(outputDir, exist_ok=True)
    outDir = os.path.abspath(outputDir).replace('\\', '/')
    iclDir = f"{outDir}/icl"

    instantiated = getInstantiatedSensors(activeInstances)
    generated = {}

    for sensorName, sensorInfo in sensors.items():
        if sensorName not in instantiated:
            continue
        iclPorts = sensorInfo.get("icl_ports", {})
        if not iclPorts:
            logging.warning(f"Sensor '{sensorName}' has no 'icl_ports' in config.json; skipping ICL extraction")
            continue

        sensorVhdl = os.path.abspath(
            os.path.join(sensorsDirectory, sensorInfo.get("vhdl_file_path", ""))
        ).replace('\\', '/')
        iclPath = f"{iclDir}/{sensorName}.icl"

        s = ""
        # 1. RTL DFT context, unique design_id per sensor.
        s += f"set_context dft -rtl -design_id {sensorName}_icl\n\n"
        s += f"set_tsdb_output_directory {outDir}/icl_tsdb\n\n"

        # 2. VHDL-2008 + read just this sensor (no packages/tech needed).
        s += "set_tool_options -allow_vhdl_2008 on\n\n"
        s += f"read_vhdl -format 2008 {sensorVhdl}\n\n"

        # 3. Select the sensor as the design and declare its IJTAG port roles.
        s += f"set_current_design {sensorName}\n\n"
        s += "set_design_level chip\n\n"
        for portType, portName in iclPorts.items():
            s += f"add_icl_ports {portName} -type {portType}\n"
        s += "\n"

        # 4. NOTE: do not add_clocks on the tck port -- 'add_icl_ports -type tck'
        #    already establishes it as the scan clock; doing both conflicts.

        # 5. Check, extract ICL, and write it out.
        s += "check_design_rules\n\n"
        s += "extract_icl\n\n"
        s += f"file mkdir {iclDir}\n"
        s += f"write_icl {iclPath} -replace\n\n"
        s += f'puts "ICL extraction for {sensorName} completed: {iclPath}"\n'

        scriptPath = os.path.join(outputDir, f"extract_icl_{sensorName}.tcl")
        with open(scriptPath, 'w') as f:
            f.write(s)
        generated[sensorName] = iclPath
        logging.info(f"ICL extraction script generated for '{sensorName}': '{scriptPath}'")
        print(f"ICL extraction script generated: {scriptPath}")

    return generated


def generateIJTAGTessentScript(activeInstances, outputDir, modifiedDir, cfgDesignId):
    """
    Generate a Tessent TCL script for IJTAG sensor insertion at the RTL level.
    All outputs land in the configuration's output directory.
    """
    os.makedirs(outputDir, exist_ok=True)
    outputDirForTcl = os.path.abspath(outputDir).replace('\\', '/')
    modifiedDirForTcl = os.path.abspath(modifiedDir).replace('\\', '/')
    tsdbDir = f"{outputDirForTcl}/tsdb_outdir"

    s = ""

    # 1. Set context: RTL-level DFT insertion with a unique design_id so Tessent
    #    can store results in the TSDB and chain multiple insertion steps.
    s += f"set_context dft -rtl -design_id {cfgDesignId}\n\n"

    # 2. Direct Tessent to store its internal database next to the other outputs.
    s += f"set_tsdb_output_directory {tsdbDir}\n\n"

    # 3. Read Tessent cell libraries (technology-specific .tcelllib files).
    #    Add paths to cellLibraryFiles in config.json.
    if cellLibraryFiles:
        for libPath in cellLibraryFiles:
            libFullPath = os.path.abspath(libPath).replace('\\', '/')
            s += f"read_cell_library {libFullPath}\n"
        s += "\n"
    else:
        s += "# No cellLibraryFiles defined in config.json — add .tcelllib paths if needed.\n\n"

    # 4. Enable VHDL-2008 mode before any read_vhdl calls.
    s += "set_tool_options -allow_vhdl_2008 on\n\n"

    # 6. Read package/library files so custom types resolve before design files.
    if packageFiles:
        for pkgPath in packageFiles:
            s += f"read_vhdl -format 2008 {os.path.abspath(pkgPath).replace(chr(92), '/')}\n"
        s += "\n"

    # 5. Read sensor VHDL entities before the design so components can be resolved.
    for sensorName, sensorInfo in sensors.items():
        sensorVhdlPath = sensorInfo.get("vhdl_file_path", "")
        if not sensorVhdlPath:
            logging.error(f"Sensor '{sensorName}' has no 'vhdl_file_path' in config.json")
            continue
        s += f"read_vhdl -format 2008 {os.path.abspath(os.path.join(sensorsDirectory, sensorVhdlPath)).replace(chr(92), '/')}\n"

    # 6. Read all modified design VHDL files for this configuration.
    for vhdlFile in sorted(glob.glob(os.path.join(modifiedDir, "*.vhd"))):
        s += f"read_vhdl -format 2008 {os.path.abspath(vhdlFile).replace(chr(92), '/')}\n"
    s += "\n"

    # 8. Set the top-level design (initial elaboration).
    s += f"set_current_design {topLevelEntity}\n\n"

    # 9. Load the per-sensor ICL produced by the Phase-1 extraction scripts
    #     (<outputDir>/icl/<sensor>.icl). This is what makes Tessent recognise the
    #     instruments -- without it the IJTAG network is empty (ICL instances=0).
    #     -force overrides the VHDL-read module definition; the design must then
    #     be re-elaborated with another set_current_design (per Tessent's advice).
    iclDir = f"{outputDirForTcl}/icl"
    instantiated = getInstantiatedSensors(activeInstances)
    iclSensors = [sn for sn in sensors if sn in instantiated and sensors[sn].get("icl_ports")]
    if iclSensors:
        for sn in iclSensors:
            s += f"read_icl {iclDir}/{sn}.icl -force\n"
        s += f"set_current_design {topLevelEntity}\n\n"
    else:
        s += "# No sensor ICL to read (run the extract_icl_*.tcl Phase-1 scripts first).\n\n"

    # 10. Declare design level. 'physical_block' (not 'chip') because RTL_DSP_TOP
    #     is an RTL block with no I/O pad cells; 'chip' would demand every TAP
    #     port be wired to a pad and forbid Tessent from creating the trst port.
    s += f"set_design_level {designLevel}\n\n"

    # 11. Mark every sensor module as a black box so Tessent never inserts DFT
    #     logic into the sensor internals or modifies its structure. Combined
    #     with the ICL above, Tessent treats each sensor as an IJTAG instrument
    #     whose scan interface is described by its (Phase-1 extracted) ICL.
    sensorNames = " ".join(sensors.keys())
    s += f"add_black_boxes -Modules {{{sensorNames}}}\n\n"

    # 12. Declare IJTAG TAP pin functions so Tessent can trace the scan network.
    #    ijtagPorts maps function names (tck/tdi/tms/tdo) to design port names.
    if ijtagPorts:
        for func, portName in ijtagPorts.items():
            s += f"set_attribute_value {portName} -name function -value {func}\n"
        s += "\n"
    else:
        s += "# No ijtagPorts defined in config.json — add tck/tdi/tms/tdo mappings.\n\n"

    # 13. Define the design clock so Tessent can perform timing-aware DRC checks.
    s += f"add_clocks 0 {clockPort} -period {clockPeriod}\n\n"

    # 14. Run design-rule checks before inserting any hardware.
    s += "check_design_rules\n\n"

    # 15. Create the DFT specification hosting the sensor instruments, then
    #     insert the IJTAG hardware that connects them to the TAP.
    s += "set spec [create_dft_specification]\n"
    s += "report_config_data $spec\n"
    s += "process_dft_specification\n\n"

    # 16. Extract the chip-level ICL by traversing the hierarchy.
    s += "extract_icl\n\n"

    # 17. Write out the instrumented design and the generated ICL network into a
    #     dedicated subdirectory. It must NOT be an ancestor of any read file
    #     (we read <outputDir>/icl/*.icl), otherwise Tessent refuses to avoid
    #     clobbering its own inputs.
    dftOutDir = f"{outputDirForTcl}/dft_inserted"
    s += f"file mkdir {dftOutDir}\n"
    s += f"write_design -output_directory {dftOutDir}\n"
    s += f"write_icl    {dftOutDir}/{topLevelEntity}.icl\n\n"

    s += "puts \"Sensor injection completed successfully!\"\n"

    scriptFilePath = os.path.join(outputDir, "inject_sensors.tcl")
    with open(scriptFilePath, 'w') as f:
        f.write(s)
    logging.info(f"Tessent script generated at: '{scriptFilePath}'")
    print(f"Tessent script generated successfully at: {scriptFilePath}")
    return scriptFilePath


def generateInstrumentedSynthesis(activeInstances, outputDir, modifiedDir, cfgDesignId, configName):
    """
    Generate Design Compiler scripts that synthesise the FULL Tessent-inserted
    design (the IJTAG network: sensors + SIBs wired to the TAP) for this
    configuration, differing only in how the sensor is treated:

      * synthesis_instrumented_<cfg>_<tech>_counted.tcl   -- sensor RTL read +
            set_dont_touch (sensor preserved & its area counted)
      * synthesis_instrumented_<cfg>_<tech>_blackbox.tcl  -- sensor RTL NOT read
            (empty black box; only the IJTAG infrastructure counted)

    Area(counted) - Area(blackbox) = sensor-internal area; Area(blackbox) = IJTAG
    network (SIBs + connections) overhead for that sensor count.

    The file list is assembled with Tcl 'glob' at DC runtime because the TSDB only
    exists after Tessent has run. The design is mixed-language: rewritten VHDL +
    generated SIB Verilog.
    """
    os.makedirs(outputDir, exist_ok=True)
    outAbs = os.path.abspath(outputDir).replace('\\', '/')
    modifiedDirAbs = os.path.abspath(modifiedDir).replace('\\', '/')

    insertedDir = f"{outAbs}/tsdb_outdir/dft_inserted_designs/{topLevelEntity}_{cfgDesignId}.dft_inserted_design"
    rewrittenDir = f"{insertedDir}/modified_rtl_files"
    sibDir = f"{outAbs}/tsdb_outdir/instruments/{topLevelEntity}_{cfgDesignId}_ijtag.instrument"

    synthClockPort = synthesisConfig.get("clockPort", clockPort)
    generics       = synthesisConfig.get("generics", {})
    instantiated   = sorted(getInstantiatedSensors(activeInstances))

    # Top-level modified file is the non-synth duplicate replaced by Tessent's
    # rewritten version, so it is skipped from the plain modified list below.
    topModifiedFile = f"modified_{topLevelEntity}.vhd"

    # Technologies come from config. Fall back to a single 'default' technology
    # built from the legacy libraryPath/clockPeriod keys if 'technologies' is
    # absent, so older configs keep working.
    technologies = synthesisConfig.get("technologies")
    if not technologies:
        technologies = {
            "default": {
                "libraryPath": synthesisConfig.get("libraryPath", ""),
                "clockPeriod": synthesisConfig.get("clockPeriod", "2"),
            }
        }

    for techName, techCfg in technologies.items():
        libraryPath = os.path.abspath(techCfg.get("libraryPath", "")).replace('\\', '/')
        synthClockPeriod = techCfg.get("clockPeriod", "2")

        for mode in ("counted", "blackbox"):
            tag = f"{configName}_{techName}_{mode}"
            reportDir = f"{outAbs}/synthesis_reports_{tag}"
            s = f"# Instrumented-design synthesis ({configName}, {techName}, {mode}) -- generated by sensor_injector.py\n"
            s += f"# Run AFTER inject_sensors.tcl (needs the Tessent TSDB in this config's tsdb_outdir).\n\n"

            # 1. Technology library + VHDL-2008.
            s += f"set synthetic_library {libraryPath}\n"
            s += f"set target_library    {libraryPath}\n"
            s += "set link_library [list $target_library $synthetic_library]\n\n"
            s += "set hdlin_vhdl_2008 true\n\n"

            # 2. Packages.
            for pkg in packageFiles:
                s += f"read_vhdl {os.path.abspath(pkg).replace(chr(92), '/')}\n"
            s += "\n"

            # 3. Sensor: read it (counted) or leave it as an unresolved black box.
            if mode == "counted":
                s += "# Sensor RTL read so its internal area is synthesised and counted.\n"
                for sn in instantiated:
                    sp = sensors[sn].get("vhdl_file_path", "")
                    if sp:
                        s += f"analyze -format vhdl {os.path.abspath(os.path.join(sensorsDirectory, sp)).replace(chr(92), '/')}\n"
                s += "\n"
            else:
                s += "# Black-box mode: sensor RTL intentionally NOT read; DC treats each\n"
                s += "# sensor instance as an empty black box (zero internal area).\n\n"

            # 4. Assemble the inserted-design VHDL: Tessent-rewritten files replace
            #    the same-named originals; the non-synth top duplicate is skipped.
            s += f"set rewritten_dir {rewrittenDir}\n"
            s += "set rewritten_files [glob -nocomplain $rewritten_dir/*.vhd]\n"
            s += "if {[llength $rewritten_files] == 0} {\n"
            s += "    echo \"ERROR: no Tessent-rewritten RTL found -- run inject_sensors.tcl first.\"\n"
            s += "    exit 1\n"
            s += "}\n"
            s += "set exclude {}\n"
            s += "foreach f $rewritten_files { lappend exclude [file tail $f] }\n\n"

            s += f"set modified_dir {modifiedDirAbs}\n"
            s += "foreach f [lsort [glob -nocomplain $modified_dir/*.vhd]] {\n"
            s += "    set base [file tail $f]\n"
            s += "    if {[lsearch -exact $exclude $base] >= 0} continue\n"
            s += f"    if {{$base eq \"{topModifiedFile}\"}} continue\n"
            s += "    analyze -format vhdl $f\n"
            s += "}\n\n"
            s += "# Tessent-rewritten (instrumented) modules.\n"
            s += "foreach f [lsort $rewritten_files] { analyze -format vhdl $f }\n\n"

            # 5. Generated SIB Verilog (the IJTAG network hardware).
            s += f"set sib_dir {sibDir}\n"
            s += "foreach f [glob -nocomplain $sib_dir/*.v] { analyze -format verilog $f }\n\n"

            # 6. Generic parameters + elaborate.
            for k, v in generics.items():
                s += f"set {k} {v}\n"
            s += "\n"
            if generics:
                paramStr = ", ".join(f"{k}=${k}" for k in generics)
                s += f'elaborate {topLevelEntity} -parameters "{paramStr}"\n\n'
            else:
                s += f"elaborate {topLevelEntity}\n\n"

            s += "link\n"
            s += "check_design\n\n"

            # 7. Preserve the sensor in counted mode. Each instance carries a
            #    different generic (e.g. SENSOR_ID), so DC uniquifies the design
            #    into variants like '<sensor>_SENSOR_ID0_...'. Match with a
            #    wildcard and guard so a missing match never hard-errors.
            if mode == "counted":
                for sn in instantiated:
                    s += f'set _sd [get_designs -quiet "{sn}*"]\n'
                    s += f'if {{[sizeof_collection $_sd] > 0}} {{\n'
                    s += f'    set_dont_touch $_sd\n'
                    s += f'}} else {{\n'
                    s += f'    echo "WARNING: no {sn}* design found to set_dont_touch"\n'
                    s += f'}}\n'
                s += "\n"

            # 8. Clock + compile.
            s += f"create_clock -name {synthClockPort} -period {synthClockPeriod} {synthClockPort}\n\n"
            s += "compile\n\n"

            # 9. Reports.
            s += f"file mkdir {reportDir}\n"
            s += f"write -f verilog -hierarchy -output {outAbs}/{topLevelEntity}_instrumented_{tag}.v\n\n"
            s += f"report_area      -nosplit -hierarchy > {reportDir}/report_area.txt\n"
            s += f"report_power     -nosplit -hierarchy > {reportDir}/report_power.txt\n"
            s += f"report_reference -nosplit -hierarchy > {reportDir}/report_references.txt\n"
            s += f"report_cell                          > {reportDir}/report_cells.txt\n\n"
            s += "exit\n"

            path = os.path.join(outputDir, f"synthesis_instrumented_{tag}.tcl")
            with open(path, 'w') as f:
                f.write(s)
            logging.info(f"Instrumented synthesis ({tag}) generated at: '{path}'")
            print(f"Instrumented synthesis ({tag}) generated: {path}")


def buildConfiguration(configName, instanceNames, outputBase):
    """
    Generate the full per-configuration flow (modified RTL + Tessent ICL/insertion
    scripts + DC synthesis scripts) into out/<configName>/, using only the named
    subset of instances. Instances may sit at any hierarchy level.
    """
    activeInstances = {}
    for n in instanceNames:
        if n not in instances:
            logging.error(f"Configuration '{configName}' references unknown instance '{n}'")
            continue
        activeInstances[n] = instances[n]

    configOut = os.path.join(outputBase, configName)
    modifiedDir = os.path.join(configOut, "modified")
    os.makedirs(configOut, exist_ok=True)
    cfgDesignId = f"{designId}_{configName}"

    logging.info(f"=== Building configuration '{configName}' ({len(activeInstances)} sensor(s)) ===")
    print(f"=== Configuration '{configName}': {sorted(activeInstances.keys())} ===")

    scanAndInjectSensors(activeInstances, modifiedDir)
    generateICLExtractionScript(activeInstances, configOut)
    generateIJTAGTessentScript(activeInstances, configOut, modifiedDir, cfgDesignId)
    generateInstrumentedSynthesis(activeInstances, configOut, modifiedDir, cfgDesignId, configName)


# Body of the standalone flow runner emitted into out/run_synthesis.py.
# Kept as a plain string (no .format) so its own braces need no escaping.
SYNTHESIS_RUNNER_TEMPLATE = '''#!/usr/bin/env python3
"""
run_synthesis.py  --  AUTO-GENERATED by sensor_injector.py

Drives the full sensor flow for EVERY configuration directory found beside this
file (each immediate subdirectory that contains an inject_sensors.tcl). Per
configuration, in order:
    1. Phase-1 ICL extraction    (tessent -shell -dofile extract_icl_<sensor>.tcl)
    2. Tessent IJTAG insertion   (tessent -shell -dofile inject_sensors.tcl)
    3. DC synthesis (all techs)  (dc_shell -f synthesis_instrumented_*.tcl)
then removes the junk files both tools scatter into that directory. Each step's
output is captured to its own log (inside the config dir) and scanned for errors.
Re-running sensor_injector.py overwrites this file.

Usage:
    python run_synthesis.py [--tessent-shell CMD] [--dc-shell CMD]
                            [--skip-tessent] [--skip-synthesis]
                            [--config NAME [--config NAME ...]]
"""

import argparse
import fnmatch
import glob
import os
import re
import subprocess
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

# Junk the EDA tools leave behind in the working directory. tsdb_outdir,
# synthesis_reports*/ and the *_instrumented_* outputs are intentional results,
# so they are NOT listed here and are never removed.
ARTIFACT_PATTERNS = [
    # Design Compiler
    "command.log", ".command.log", "*.svf",
    "WORK", "alib*", "crte*",
    "*.syn", "*.mr", "*.pvl", "*.db_postlink",
    "*.log~", "filenames.log", "*.svf.bak",
    # Tessent
    "tessent_*.log", "*.dofile.log",
]

# Matches DC "Error: ..." and Tessent "//  Error: ..." transcript lines.
ERROR_RE = re.compile(r"^\\s*(//\\s*)?Error:", re.MULTILINE)


def find_config_dirs():
    """Immediate subdirectories of HERE that contain an inject_sensors.tcl."""
    dirs = []
    for entry in sorted(os.listdir(HERE)):
        path = os.path.join(HERE, entry)
        if os.path.isdir(path) and os.path.isfile(os.path.join(path, "inject_sensors.tcl")):
            dirs.append(path)
    return dirs


def clean_artifacts(workdir, pre_existing):
    """Remove tool junk created during the run (never pre-existing files)."""
    removed = []
    for entry in os.listdir(workdir):
        if entry in pre_existing:
            continue
        if not any(fnmatch.fnmatch(entry, pat) for pat in ARTIFACT_PATTERNS):
            continue
        path = os.path.join(workdir, entry)
        try:
            if os.path.isdir(path) and not os.path.islink(path):
                shutil.rmtree(path)
            else:
                os.remove(path)
            removed.append(entry)
        except OSError as exc:
            print("    [warn] could not remove artifact '%s': %s" % (entry, exc))
    return removed


def run_step(name, cmd, workdir, log_path):
    """Run one EDA step, capturing output. Returns (returncode, error_lines)."""
    print("=== %s: %s ===" % (name, " ".join(cmd)))
    with open(log_path, "w", encoding="utf-8") as log:
        proc = subprocess.run(cmd, cwd=workdir, stdout=log, stderr=subprocess.STDOUT, text=True)
    with open(log_path, "r", encoding="utf-8", errors="replace") as log:
        log_text = log.read()
    error_lines = [ln.strip() for ln in log_text.splitlines() if ERROR_RE.match(ln)]
    return proc.returncode, error_lines


def report(name, rc, error_lines, log_path):
    """Print step result. Returns True on success."""
    if rc != 0 or error_lines:
        print("[ERROR] %s FAILED (rc=%d, %d error line(s)). See %s"
              % (name, rc, len(error_lines), log_path))
        for ln in error_lines[:20]:
            print("    " + ln)
        if len(error_lines) > 20:
            print("    ... and %d more" % (len(error_lines) - 20))
        return False
    print("[OK] %s completed. Log: %s" % (name, log_path))
    return True


def run_config(config_dir, args):
    """Run the full Tessent + DC flow inside one configuration directory."""
    name = os.path.basename(config_dir)
    print("\\n##### Configuration '%s' (%s) #####" % (name, config_dir))
    inject_tcl = os.path.join(config_dir, "inject_sensors.tcl")
    pre_existing = set(os.listdir(config_dir))
    ok = True
    try:
        # 1. Phase-1 ICL extraction (one script per sensor).
        if not args.skip_tessent:
            for extract_tcl in sorted(glob.glob(os.path.join(config_dir, "extract_icl_*.tcl"))):
                step = "ICL extraction (%s/%s)" % (name, os.path.basename(extract_tcl))
                log = os.path.join(config_dir, os.path.basename(extract_tcl) + ".log")
                rc, errs = run_step(step,
                                    [args.tessent_shell, "-shell", "-dofile", extract_tcl],
                                    config_dir, log)
                if not report(step, rc, errs, log):
                    return False

        # 2. Tessent IJTAG insertion.
        if not args.skip_tessent:
            if not os.path.isfile(inject_tcl):
                print("[FATAL] inject_sensors.tcl not found: %s" % inject_tcl)
                return False
            log = os.path.join(config_dir, "tessent_run.log")
            rc, errs = run_step("Tessent IJTAG insertion (%s)" % name,
                                [args.tessent_shell, "-shell", "-dofile", inject_tcl],
                                config_dir, log)
            if not report("Tessent (%s)" % name, rc, errs, log):
                return False

        # 3. DC synthesis -- every synthesis_instrumented_*.tcl in this config dir.
        if not args.skip_synthesis:
            synth_scripts = sorted(glob.glob(os.path.join(config_dir, "synthesis_instrumented_*.tcl")))
            if not synth_scripts:
                print("[FATAL] no synthesis_instrumented_*.tcl in %s -- run sensor_injector.py first." % config_dir)
                return False
            for tcl in synth_scripts:
                label = os.path.basename(tcl)[len("synthesis_instrumented_"):-len(".tcl")]
                log = os.path.join(config_dir, "dc_shell_%s.log" % label)
                rc, errs = run_step("DC synthesis (%s)" % label,
                                    [args.dc_shell, "-f", tcl], config_dir, log)
                if not report("DC synthesis (%s)" % label, rc, errs, log):
                    ok = False
    finally:
        removed = clean_artifacts(config_dir, pre_existing)
        if removed:
            print("Cleaned %d artifact(s) in %s: %s" % (len(removed), name, ", ".join(sorted(removed))))
    return ok


def main():
    parser = argparse.ArgumentParser(description="Run the Tessent + DC synthesis flow for every sensor-count configuration.")
    parser.add_argument("--tessent-shell", default="tessent", help="tessent executable name/path")
    parser.add_argument("--dc-shell", default="dc_shell", help="dc_shell executable name/path")
    parser.add_argument("--skip-tessent", action="store_true", help="do not run the Tessent steps (reuse existing TSDB)")
    parser.add_argument("--skip-synthesis", action="store_true", help="do not run the DC synthesis steps")
    parser.add_argument("--config", action="append", default=None,
                        help="only run the named configuration(s); repeatable")
    args = parser.parse_args()

    config_dirs = find_config_dirs()
    if not config_dirs:
        print("[FATAL] no configuration subdirectories found beside run_synthesis.py -- run sensor_injector.py first.")
        return 1
    if args.config:
        wanted = set(args.config)
        config_dirs = [d for d in config_dirs if os.path.basename(d) in wanted]
        if not config_dirs:
            print("[FATAL] none of the requested configurations exist: %s" % ", ".join(sorted(wanted)))
            return 1

    print("Configurations to run: %s" % ", ".join(os.path.basename(d) for d in config_dirs))
    overall_ok = True
    for config_dir in config_dirs:
        if not run_config(config_dir, args):
            overall_ok = False

    if not overall_ok:
        print("\\n[ERROR] one or more configurations failed -- see the per-config logs.")
        return 1
    print("\\n[OK] all configurations completed. Reports in <config>/synthesis_reports_*/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
'''


def generateSynthesisRunner():
    """
    Emit a standalone Python runner (out/run_synthesis.py) that iterates over the
    per-configuration subdirectories, running Tessent IJTAG insertion then dc_shell
    synthesis for each, cleaning tool junk along the way.
    """
    outputDir = os.path.join(workingDirectory, "out")
    os.makedirs(outputDir, exist_ok=True)
    runnerPath = os.path.join(outputDir, "run_synthesis.py")
    with open(runnerPath, 'w', encoding='utf-8') as f:
        f.write(SYNTHESIS_RUNNER_TEMPLATE)
    logging.info(f"Synthesis runner generated at: '{runnerPath}'")
    print(f"Synthesis runner generated successfully at: {runnerPath}")
    return runnerPath


if __name__ == "__main__":
    getConfig()

    # Create the output directory first so the log file lands inside it
    outputBase = os.path.join(workingDirectory, "out")
    os.makedirs(outputBase, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format='%(levelname)s: %(message)s',
        filename=os.path.join(outputBase, "sensor_injector.log"),
        filemode='w'
    )

    # A configuration maps a name -> the subset of instances integrated in it.
    # Falls back to a single 'all' configuration (every instance) when none are
    # declared, so older configs keep working.
    configs = configurations
    if not configs:
        configs = {"all": list(instances.keys())}
        logging.info("No 'configurations' in config.json; defaulting to a single 'all' configuration")

    for configName, instanceNames in configs.items():
        buildConfiguration(configName, instanceNames, outputBase)

    generateSynthesisRunner()

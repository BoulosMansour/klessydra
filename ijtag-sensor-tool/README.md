# ijtag-sensor-tool

A comprehensive tool for automatically injecting IEEE 1687 (IJTAG) sensors into VHDL designs and generating hierarchical test networks. The tool parses VHDL entities, manages sensor configurations, and generates Tessent scripts for RTL-level sensor integration.

## Overview

**ijtag-sensor-tool** provides:
- **VHDL Entity Parsing**: Extracts ports and generics from VHDL entities using robust regex parsing
- **Hierarchical Design Exploration**: Discovers component dependencies across the design hierarchy
- **Sensor Injection**: Automatically injects IJTAG sensors into designated locations using pragmas
- **Tessent Integration**: Generates scripts for hierarchical IJTAG routing via Tessent

## Configuration (`config.json`)

```json
{
  "topLevelEntity": "cpu_top",
  "workingDirectory": "src",
  "sensorsDirectory": "sensors",
  "sensors": {
    "thermal_sensor": {
      "vhdl_file_path": "thermal_sensor.vhd",
      "icl_blueprint_path": "../sensor_blueprints.icl"
    }
  },
  "instances": {
    "thermal_inst_0": {
      "sensor_name": "thermal_sensor",
      "generic_maps": {
        "DATA_WIDTH": "8",
        "THRESHOLD": "100",
        "SENSOR_ID": "1",
        "ENABLE_FILTERING": "true"
      },
      "port_maps": {
        "clk": "sys_clk",
        "rst_n": "sys_rst_n",
        "temp_in": "axi_data_in(7 downto 0)",
        "temp_out": "temp_value",
        "alert": "temp_alert"
      },
      "tessent_path": "/cpu_top/thermal_inst_0"
    }
  }
}
```

## Global Configuration Properties

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| topLevelEntity | String | Yes | The name of the top-level VHDL entity (without `.vhd` extension). The tool starts the hierarchy exploration from this entity. |
| workingDirectory | String | Yes | The base directory containing all VHDL source files. The tool recursively searches this directory for component declarations. |
| sensorsDirectory | String | No | The directory containing sensor VHDL files and ICL blueprints. Used as the base path when resolving `vhdl_file_path` values inside the `sensors` object. |
| sensors | Object | Yes | Defines available sensors with their VHDL files and ICL blueprint paths. |
| instances | Object | Yes | Defines where and how sensors are instantiated in the design. |

## Sensors Definition

Each sensor in the `sensors` object must define:

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| vhdl_file_path | String | Yes | Path to the sensor's VHDL entity file, relative to `sensorsDirectory`. |
| icl_blueprint_path | String | Yes | Path to the sensor's ICL blueprint file defining its test interface, relative to `sensorsDirectory`. |

## Instance Properties

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| sensor_name | String | Yes | The name of the sensor to instantiate (must be a key in the `sensors` object). |
| generic_maps | Object | No | VHDL generic overrides as a key-value mapping (e.g., `{"DATA_WIDTH": "8"}`). |
| port_maps | Object | No | Port mappings from sensor ports to design signals (e.g., `{"clk": "sys_clk"}`). Any port defined on the sensor entity but omitted here is automatically mapped to `open`. All keys must match port names declared in the sensor's VHDL entity. |
| tessent_path | String | No | The hierarchical instance path used in the generated Tessent script (e.g., `"/cpu_top/thermal_inst_0"`). Required for `set_instrument_instances` to be emitted for this instance. |

## Using the Tool

### 1. Mark Injection Points in Your VHDL

Add two pragmas in the target VHDL file's architecture — one in the declarative region and one in the statement region:

```vhdl
-- SENSOR-DECLARATION: thermal_sensor
```

Place this in the declarative region (before `begin`). The identifier after the colon must be the **sensor entity name** as it appears in the sensor's VHDL file, not the instance name.

```vhdl
-- SENSOR-INSTANTIATION: thermal_inst_0
```

Place this in the statement region (after `begin`). The identifier must match an instance key in `config.json`.

If two instances share the same sensor entity, only one `SENSOR-DECLARATION` pragma for that entity is needed — the tool replaces it on first encounter and skips duplicates.

### 2. Configure the Tool

Edit `config.json` with:
- Your top-level entity and working directory
- Available sensors and their file paths
- Instances with port/generic mappings and Tessent paths

### 3. Run the Sensor Injector

`sensor_injector.py` must be run from the **project root** — the directory that contains `config.json`. The generated Tessent script uses absolute paths, so Tessent can be invoked from any directory.

```bash
# from the project root
python sensor_injector.py
```

This will:
- Scan all VHDL files in `workingDirectory` (excluding previously generated `modified/` and `out/` subdirectories)
- Replace declaration pragmas with `component` declarations
- Replace instantiation pragmas with `port map` / `generic map` instantiations
- Write modified files to `workingDirectory/modified/`
- Generate a Tessent integration script at `workingDirectory/out/inject_sensors.tcl`
- Write a detailed run log to `workingDirectory/out/sensor_injector.log`

### 4. Run the Tessent Script

After the injector completes, invoke Tessent. All file references inside the generated TCL (VHDL sources, ICL blueprints, output paths) are absolute, so Tessent can be started from any directory.

```bash
# from the project root — batch / dofile mode
tessent -shell -dofile workingDirectory/out/inject_sensors.tcl
```

Or source it from within an interactive Tessent session that was started at the project root:

```tcl
source workingDirectory/out/inject_sensors.tcl
```

Replace `workingDirectory` with the value you set in `config.json` (e.g., `src`).

Tessent will:
1. Read the modified VHDL files from `workingDirectory/modified/`
2. Read the ICL blueprint(s) listed in `config.json`
3. Build the IJTAG network and run design rule checks
4. Write the final VHDL to `workingDirectory/out/injected_design.vhd`
5. Write the extracted chip-level ICL to `workingDirectory/out/injected_network.icl`

## Output Structure

```
workingDirectory/
├── modified/          # Modified VHDL files with pragmas replaced
│   └── modified_<original_filename>.vhd
└── out/
    ├── inject_sensors.tcl     # Generated Tessent script
    └── sensor_injector.log    # Detailed run log
```

## Port Mapping Behaviour

When building the `port map` for an instance, the tool:

1. Parses the sensor entity's VHDL to discover all declared ports.
2. Validates that every key in `port_maps` corresponds to an actual port on the entity; mismatches are logged as errors and the instance is skipped.
3. For any entity port **not** listed in `port_maps`, a warning is logged and the port is automatically mapped to `open`.

## IJTAG Port Connections

IJTAG ports (`ijtag_tdi`, `ijtag_tdo`, `ijtag_tck`, `ijtag_tms`) **must be explicitly connected** to real signals in `port_maps` — do not map them to `open`.

Tessent's `extract_icl` works by tracing IJTAG signal paths structurally through the VHDL hierarchy. If an IJTAG port is tied to a constant (which `open` produces when a default value is present) or has no structural path to a top-level port, extraction fails.

The correct setup:
1. Add IJTAG ports to every parent entity that contains a sensor instance.
2. Connect the sensor's IJTAG ports to those parent entity ports in `port_maps`.

```json
"port_maps": {
    "ijtag_tck": "ijtag_tck",
    "ijtag_tms": "ijtag_tms",
    "ijtag_tdi": "ijtag_tdi",
    "ijtag_tdo": "ijtag_tdo"
}
```

// Thermal Sensor ICL Blueprint
// IEEE 1687 instrument definition for the thermal_sensor VHDL entity.
// Syntax based on Origen-SDK/ijtag open-source examples (github.com/Origen-SDK/ijtag).

Module thermal_sensor {

    // Port names must match the VHDL entity port names exactly
    TCKPort    ijtag_tck;
    SelectPort ijtag_tms;
    ScanInPort ijtag_tdi;
    ScanOutPort ijtag_tdo { Source ThermalConfigReg[0]; }

    // Client interface consumed by the upstream Tessent IJTAG router
    ScanInterface client {
        Port ijtag_tck;
        Port ijtag_tms;
        Port ijtag_tdi;
        Port ijtag_tdo;
    }

    // 8-bit temperature read register — captures temp_value[7:0]
    ScanRegister ThermalReadReg[7:0] {
        ScanInSource ijtag_tdi;
        CaptureSource ThermalReadReg;
        ResetValue 8'h00;
    }

    // 9-bit configuration register — bits [8:1] = threshold, [0] = enable_alert
    // Scan input chains from the scan-output end ([0]) of ThermalReadReg
    ScanRegister ThermalConfigReg[8:0] {
        ScanInSource ThermalReadReg[0];
        CaptureSource ThermalConfigReg;
        ResetValue 9'h000;
    }
}

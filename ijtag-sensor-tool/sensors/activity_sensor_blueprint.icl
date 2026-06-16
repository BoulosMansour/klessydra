// Activity Sensor IEEE 1687 ICL Blueprint
// Tessent uses this to trace the IJTAG scan path through the sensor.

Module activity_sensor {
    TCKPort    ijtag_tck;
    SelectPort ijtag_tms;
    ScanInPort ijtag_tdi;
    ScanOutPort ijtag_tdo { Source ActivityReg[0]; }

    ScanInterface client {
        Port ijtag_tdi;
        Port ijtag_tdo;
        Port ijtag_tck;
        Port ijtag_tms;
    }

    // 8-bit activity count register — Tessent traces the RTL capture path structurally
    ScanRegister ActivityReg[7:0] {
        ScanInSource ijtag_tdi;
        CaptureSource ActivityReg;
        ResetValue 8'h00;
    }

    // Alert flag register chained after the activity count register
    ScanRegister AlertReg[0:0] {
        ScanInSource ActivityReg[0];
        CaptureSource AlertReg;
        ResetValue 1'h0;
    }
}

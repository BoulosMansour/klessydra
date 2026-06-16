//-------------------------------------------------
//  File created by: Tessent Shell
//          Version: 2022.3
//       Created on: Sun Jun 14 15:14:18 EDT 2026
//-------------------------------------------------


Module activity_sensor {
   // Created by ICL extraction
   CaptureEnPort ijtag_ce;
   ResetPort ijtag_reset {
      ActivePolarity 1;
   }
   ShiftEnPort ijtag_se;
   SelectPort ijtag_sel;
   ScanInPort ijtag_si;
   ScanOutPort ijtag_so;
   TCKPort ijtag_tck;
   Attribute tessent_design_format = "vhdl_2008";
   Attribute icl_extraction_date = "Sun Jun 14 15:14:17 EDT 2026";
   Attribute created_by_tessent_icl_extract = "true";
   Attribute tessent_design_id = "activity_sensor_icl";
   Attribute tessent_design_level = "chip";
   Attribute tessent_is_physical_module = "true";
}

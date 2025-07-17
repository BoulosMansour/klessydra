set search_path [list . /home/e.rodriguez/tech_lib/ [getenv "SYNOPSYS"]]
set synthetic_library dw_foundation.sldb
set target_library NangateOpenCellLibrary.db
set link_library [list $target_library $synthetic_library]

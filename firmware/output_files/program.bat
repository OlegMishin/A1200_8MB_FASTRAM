rem bin-x64\openocd.exe -f scripts\interface\ftdi\um232h.cfg -c "adapter_khz 400" -c "transport select jtag" -c "jtag newtap ATF1504AS tap -irlen 3 -expected-id 0x0150403f" -c init -c "svf VC20FINAL-V3-2.svf" -c "sleep 200" -c shutdown

"E:\openocd-v0.11.0\bin\openocd.exe" -f "E:\openocd-v0.11.0\scripts\interface\altera-usb-blaster.cfg" -c init -c "svf pld_ram.svf" -c "sleep 200" -c shutdown
pause
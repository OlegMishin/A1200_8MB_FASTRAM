# A1200_8MB_FASTRAM

8MB FastRAM expansion for Amiga 1200 (with RTC).

Complete 5V design using Microchip ATF1508 CPLD.
Source code based on "Amiga 600 8 megabytes fastRAM board": http://lvd.nedopc.com/Projects/a600_8mb/index.html and some other sources I forgot :)

An aim of this design is to learn Verilog and 68k CPU. So the pcb has a TEST connector for debug and future expansion.

Firmware:

At the moment supports only 8MB configuration.


PCB:

4-layers, gerber files included for production. Designed in Altium Designer.

![изображение](https://user-images.githubusercontent.com/81614352/143093321-a98c7f1c-e393-42e7-b37e-cb9f996d0e7c.png)


First working sample (Rev 0). Had to cut a bit as it was not fit to the Amiga trapdoor place.

![изображение](https://user-images.githubusercontent.com/81614352/143570562-13b7ab25-e2c9-43bb-961f-28bec9fde4e3.png)




# Revision 2 came as a bug fix:
1. Fixed short circuit between data bus by a via.
2. Corrected pcb outline to fit Amiga without any mechanical modification.
3. Added crystal footprint if the RTC is M6242B 

This revision has not yet been tested but DRC issues no errors.

![image](https://user-images.githubusercontent.com/81614352/221422382-829dd254-3c9b-4f75-8457-412ce4442fc7.png)


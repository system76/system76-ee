# Power Testing Instructions

___
## Test Setup
+ All Device Under Test (DUT) evaluations should have the background image set to an RGB of (130, 130, 130).
+ DUT power settings are set to "Blank Screen" after 15min and "Suspend" after 30min.
+ Recommended to utilize a timer.

### Desktops
#### i. Sub-300VA Power Demand
Confirm the following:
1. Power line conditioner is connected to 120Vac wall outlet.
1. AC power source is connected to power line conditioner. Settings should be set to 115V at 60Hz, and Communication set to USB.
1. DUT is connected to AC power source.
1. If DUT has an ethernet connection, connect it to a network switch/router and is confirm it is the only device connected. 
1. Assessor's computer should be connected to the AC power source's USB connection.
1. Desktop monitor is connected to either the power line conditioner or a separate power source (i.e. wall outlet).
1. Wired mouse and keyboard are connected to DUT USB.


#### ii. Above 300VA Power Demand


### Laptops
MAKE SURE LAPTOP IS FULLY CHARGED BEFORE TESTING.
#### i. Sub-300VA Power Demand
Confirm the following:
1. Power line conditioner is connected to 120Vac wall outlet.
1. AC power source is connected to power line conditioner. Settings should be set to 115V at 60Hz, and Communication set to USB.
1. Device Under Test (DUT) is connected to AC power source.
1. If DUT has an ethernet connection, connect it to a network switch/router and is confirm it is the only device connected. 
1. Assessor's computer should be connected to the AC power source's USB connection.


#### ii. Above 300VA Power Demand

___
## Test Procedure
From start to finish, expect a single test to run around 45 minutes. Each DUT needs to be fully tested at least twice.

### I. Test Conditions
Record the following:
1. Temperature (&deg;C)
2. Relative Humidity (%)
3. Ambient Light (Lux) &#8594; Only if the integrated display adjusts to ambient light.
4. Supply Voltage (V)
5. Supply Frequency (Hz)
6. Ethernet Connection
7. Total Harmonic Distortion (%) &#8594; Probe the hot lead and calculate THD


### II. Short Idle
1. Turn on machine and log in. Make sure all windows are closed. 
2. Let the machine idle for a couple of minutes such that the DUT reaches a steady state.
3. Run 9801-logger.jl to collect at least 5 minutes (300sec) of data. Make sure the screen never dims or goes blank during data collection.

### III. Long Idle
1. Let the screen go blank (do not force it).
2. After a couple of minutes, run 9801-logger.jl again to collect at least 5 minutes of data. Make sure the DUT does not suspend during data collection.


### IV. Sleep/Suspend
1. Let the DUT suspend (do not force it).
2. After a couple of minutes run 9801-logger.jl again to collect at least 5 minutes of data. Make sure the DUT does not wake during data collection.


### V. Off
1. Wake the DUT and command it to power off.
2. After a couple of minutes, run 9801-logger.jl again to collect at least 5 minutes of data. 
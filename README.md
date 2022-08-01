# Power Testing
Updated: 2022/07/27

Resources:
+ [PyVISA Docs](https://pyvisa.readthedocs.io/en/latest/introduction/getting.html)
+ [PyVISA Tutorial](https://goughlui.com/2021/03/28/tutorial-introduction-to-scpi-automation-of-test-equipment-with-pyvisa/)

Packages Required:
+ pyvisa
+ pyvisa-py
+ pyusb

Helpful Commands in Terminal Emulator:
+ pyvisa-info
+ pyvisa-shell

Confirmed to work with:
+ BK Precision 9801
+ Keysight EDUX1052A


On Linux, you may come across a `udev` issue, preventing you from having permissions to communicate with the device. The solution can be found [here](https://stackoverflow.com/questions/66480203/pyvisa-not-listing-usb-instrument-on-linux).


___
## VISA and SCPI

[Virtual Instrument Software Architecture (VISA)](https://en.wikipedia.org/wiki/Virtual_instrument_software_architecture) in the standardized protocol for connecting to test instruments. The IVI Foundation maintains the standard drivers.

[Standard Commands for Programmable Instruments (SCPI)](https://en.wikipedia.org/wiki/Standard_Commands_for_Programmable_Instruments) is a standardized set of commands to program test instruments. IEEE defined the standard syntax and commands for programming test instruments.

Recognizing your USBTMC connection is critical, especially if you have multiple VISA devices connected. An example USBTMC connection is `USB0::65535::38912::802XXXXXXX::0::INSTR`

In the *pyvisa-shell*, one can open an USB connection and query the instrument's product information (manufacturer, model number, serial number, and firmware revision number) with the following command:
```
query *IDN?
```



#### BK Precision 9801

Within the *pyvisa-shell*, one can run the following:

```
query MEAS:VOLT?;:MEAS:FREQ?;:MEAS:POW:REAL?;:MEAS:POW:APP?
```

This line breaks down output into the Output Voltage, Frequency, Real Power and Apparent Power.


#### Keysight EDUX1052A

Within the *pyvisa-shell*, one can do the following:

```
query MEAS:VRMS? DISP,AC,CHAN1
```

This line outputs the AC RMS Voltage within the DISPlay window and from CHANnel 1.

___
## Test Setup
The Device Under Test (DUT) will connect to the AC-out of the AC Power Source which should have the following requirements fulfilled:

|||
|------------------|:------------:|
| True RMS Voltage | 115V &pm; 1% |
| Frequency        | 60Hz &pm; 1% |
| Total Harmonic Distortion (THD) | <2% for PSU <1,500W ; <5% for PSU >1,500W |

The THD (%) is calculated as the root-sum-square (RSS) of the harmonic voltages divided by the fundamental voltage:

$$ THD = 100 * \frac{ \sqrt{ \sum_{i=1}^N V_{RMS,i}^2 } }{ V_{RMS,Fundamental} } $$

Importance of True RMS measurements can be explained [here](https://www.fluke.com/en-us/learn/blog/electrical/what-is-true-rms).

___
## Programs
#### 9801-logger.jl

This [Julia](https://julialang.org/) program is used to query, plot and save data from the BK Precision 9801 AC Power Source used for power testing/monitor.

The inputs are as follows:

```
usage: 9801 Logger [-c] [-g] [-t TITLE] [-o CSV-NAME]
                   [-p POLLING-RATE] [-r RUN-TIME] [--pretty] [-h]

Connect to BK precision power supply and log recordings in both GUI
and CSV

optional arguments:
  -c, --no-csv          Skip saving output to a csv file
  -g, --no-gui          Do not create a GUI ouput. Information will be
                        printed via CLI.
  -t, --title TITLE     Set a super title for the gui graph output
  -o, -n, --csv-name CSV-NAME
                        The name given to the generated csv output.
  -p, --polling-rate POLLING-RATE
                        The rate the 9801 is polled in Hertz (Hz).
                        Also increases gui update rate and output
                        lines output to csv. Too high of a value can
                        waste memory and cause race conditions. No
                        higher than 10 is recommended. Must be evenly
                        divisible into 1 second (1, 2, 5 or 10).
                        (type: Int64, default: 2)
  -r, --run-time RUN-TIME
                        The length of time the test will run in
                        seconds. This may be adjusted automatically to
                        match the polling rate. (type: Int64, default:
                        330)
  --pretty              Make the graph theme dark
  -h, --help            show this help message and exit
  ```

Example command in the terminal that creates the plot's supertitle "2022/07/27 MEER5 Power Off", outputs the data to "20220727_MEER5FNH_Off.csv", and has a polling rate of 10Hz:

```
julia 9801-logger.jl -t "2022/07/27 MEER5 Power Off" -o "20220727_MEER5FNH_Off.csv" -p 10
```


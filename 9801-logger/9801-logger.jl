using PyCall
using Dates
using CSV
using Plots
using DataFrames
using ArgParse

### Helper Functions
function get_connection(rm)
  resources = rm.list_resources()
  if (length(resources) == 1)
    print("Only one connection available.\nOpening: '$(resources[1])'\n")
    rm.open_resource(resources[1])
  elseif (length(resources) > 1)
    println("More than one open connection.")
    for (index, name) in enumerate(resources)
      println("  [$index] $name")
    end
    print("Please enter a number to choose one: ")
    input = parse(Int, readline())
    rm.open_resource(resources[input])
  else
    print("No connections available. Exiting.\n")
    nothing
  end
end

function concat_cmd(cmds)
  if (typeof(cmds) == String)
    cmds
  elseif (length(cmds) > 1)
    join(cmds, ";:")
  else
    cmds[1]
  end
end

function into_recording(out)
  r = map(rec -> replace(rec, " " => "", "\n" => "") , split(out, ";"))
  i = x -> parse(Float64, x)
  Recording(Dates.now(), i(r[1]), i(r[2]), i(r[3]), i(r[4]))
end

function unlock_spin(timer)
  global spin_lock = false
end

# Use modified point slope form to calculate the time the recording line crossed the
# threshold line, then add that point to the recordings, bounds, and 
function interpolate_points(times, recordings, bounds, out_recordings, time, threshold, fillWithNaN=false)
  slope = (out_recordings - last(recordings)) / (time - last(times))
  interpolated_time = (threshold - out_recordings)/slope + time
  push!(times, interpolated_time)
  push!(recordings, threshold)
  push!(bounds, fillWithNaN ? NaN : threshold)
  @assert (Inf != interpolated_time)
  @assert (-Inf != interpolated_time)
  @assert (interpolated_time < time)
end

# This function fixes a bug in Plots.jl, when displaying many plots on the same windws
# like this script does Plots.jl will crash with a out of `Bounds` error if the number
# of points differs in each plot. Having the same number of points one each graph
# seems to fix this issue.
function fix_bounds_bug(freqs, reals, apps, out)
  push!(freqs, out.freq)
  push!(reals, out.real)
  push!(apps,  out.app )
end

function parse_commandline()
    s = ArgParseSettings(prog="9801 Logger",
		         description="Connect to BK precision power supply and log recordings in both GUI and CSV",
			 commands_are_required=false
			)

    @add_arg_table! s begin
        "--no-csv", "-c"
            help = "Skip saving output to a csv file"
	    action = :store_true
	"--no-gui", "-g"
	    help = "Do not create a GUI ouput. Information will be printed via CLI."
	    action = :store_true
	"--title", "-t"
	    help = "Set a super title for the gui graph output"
	    arg_type = String
        "--csv-name", "-o", "-n"
            help = "The name given to the generated csv output."
            arg_type = String
        "--polling-rate", "-p"
	    help = "The rate the 9801 is polled in Hertz (Hz). Also increases gui update rate and output lines output to csv. Too high of a value can waste memory and cause race conditions. No higher than 10 is recommended. Must be evenly divisible into 1 second (1, 2, 5 or 10)."
	    arg_type = Int
	    default = 2
	"--run-time", "-r"
	    help = "The length of time the test will run in seconds. This may be adjusted automatically to match the polling rate."
	    default = 330
	    arg_type = Int
	"--volt-min", "-m"
	    help = "This is a purely graphical change. Any value lower than this will be red on the Volts graph."
	    arg_type = Float64
	"--volt-max", "-M"
	    help = "This is a purely graphical change. Any value higher than this will be red on the Volts graph."
	    arg_type = Float64
	"--pretty"
	    help = "Make the graph theme dark"
	    action = :store_true
    end

    return parse_args(s)
end

struct Recording
  time::DateTime
  volt::Float64
  freq::Float64
  real::Float64
  app::Float64
end

### Consts
const PARSED_ARGS = parse_commandline()
csv_name = PARSED_ARGS["csv-name"]
if (PARSED_ARGS["polling-rate"] in (1, 2, 5, 10))
  const POLLING_RATE = PARSED_ARGS["polling-rate"]
else
  println("Invalid polling rate. Setting to default of 2Hz.")
  const POLLING_RATE = 2
end
const NO_CSV = PARSED_ARGS["no-csv"]
const NO_GUI = PARSED_ARGS["no-gui"]
const RUN_TIME = PARSED_ARGS["run-time"]
const SUPER_TITLE = isnothing(PARSED_ARGS["title"]) ? "" : PARSED_ARGS["title"]
const PRETTY = PARSED_ARGS["pretty"]
const err = 0.01 # voltage tolerance
const VOLT_MIN = isnothing(PARSED_ARGS["volt-min"]) ? (1 - err) * 115 : PARSED_ARGS["volt-min"]
const VOLT_MAX = isnothing(PARSED_ARGS["volt-max"]) ? (1 + err) * 115 : PARSED_ARGS["volt-max"]

const PYVISA = pyimport("pyvisa")
const RM = PYVISA.ResourceManager()
const CONNECTION = get_connection(RM)

const VOLT = "MEAS:VOLT?"
const FREQ = "MEAS:FREQ?"
const REAL = "MEAS:POW:REAL?"
const APP  = "MEAS:POW:APP?"

const ITER_COUNT_MAX = POLLING_RATE * RUN_TIME
global spin_lock = false


### Main
try
  if (!isnothing(CONNECTION))

    ### Argument parsing
    println("9801 Logger:")
    is_polling_default = POLLING_RATE == 2 ? "(Default)" : ""
    is_name_default = isnothing(csv_name) ? "(Default)" : ""
    is_runtime_default = RUN_TIME == 330 ? "(Default)" : ""
    is_volt_min_default = VOLT_MIN == (1 - err) * 115 ? "(Default)" : ""
    is_volt_max_default = VOLT_MAX == (1 + err) * 115 ? "(Default)" : ""
    csv_name = isnothing(csv_name) ? Dates.format(Dates.now(), "yyyy-mm-dd_HH:MM:SS") * ".csv" : csv_name
    println("  Polling Rate => $(POLLING_RATE)Hz $is_polling_default")
    println("  Run Time     => $RUN_TIME seconds $is_runtime_default")
    println("  Volt Min     => $VOLT_MIN seconds $is_volt_min_default")
    println("  Volt Max     => $VOLT_MAX seconds $is_volt_max_default")
    if (!NO_CSV)
      println("  Output File  => $csv_name $is_name_default")
    end

    global spin_lock
    iter_count = 0
    recordings = []
    timestamps = []
    times      = []
    volts      = []
    volts_bounds = []
    freqs      = []
    reals      = []
    apps       = []

    global NO_GUI
    if (!NO_GUI)
      gr()
      if (PRETTY)
        theme(:dark)
      end
    end

    start_time = missing

    t = Timer(unlock_spin, 0, interval=(1 / POLLING_RATE))
    wait(t)
    # Use a naieve spin lock to keep poll timings as close to the
    # timer as possible
    while (iter_count <= ITER_COUNT_MAX)
      sleep(0.001)
      if (!spin_lock)
	global NO_GUI
	if (!NO_GUI)
	  p1 = plot(times, [volts, volts_bounds], label=false, xlabel="Runtime [s]", ylabel="Voltage [V]")
	  p2 = plot(times, freqs, label=false, xlabel="Runtime [s]", ylabel="Frequency [Hz]")
	  p3 = plot(times, [reals, apps], label=["Real" "Apparent"], xlabel="Runtime [s]", ylabel="Power [W]", legend=:outertopright)
	  display(plot(p1, p2, p3, layout=@layout([p1 p2; p3]), plot_title=SUPER_TITLE))
	end

        if (ismissing(start_time))
	  start_time = Dates.now()
        end

        out = CONNECTION.query(concat_cmd([VOLT, FREQ, REAL, APP])) |> into_recording
        time = round((Dates.value(out.time) - Dates.value(start_time)) / 1000, digits = 3)
	timestamp =  Dates.format(out.time, "yyyy-mm-dd HH:MM:SS.sss")

	volt_safe = false
	current = out.volt
	if (!NO_GUI && length(volts) > 0)
	  global VOLT_MIN
	  global VOLT_MAX
	  prev = last(volts)
	  # Describes the intersection and slope of the line
	  # Goes up from below MIN to above MAX
          if (prev < VOLT_MIN && current > VOLT_MAX)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MIN)
	    fix_bounds_bug(freqs, reals, apps, out)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, (VOLT_MIN + VOLT_MAX)/2, true)
	    fix_bounds_bug(freqs, reals, apps, out)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MAX)
	    fix_bounds_bug(freqs, reals, apps, out)
	  # Goes down from above MAX to below MIN
	  elseif (prev > VOLT_MAX && current < VOLT_MIN)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MAX)
	    fix_bounds_bug(freqs, reals, apps, out)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, (VOLT_MIN + VOLT_MAX)/2, true)
	    fix_bounds_bug(freqs, reals, apps, out)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MIN)
	    fix_bounds_bug(freqs, reals, apps, out)
	  # Goes up from middle above MAX
	  elseif (VOLT_MIN < prev < VOLT_MAX && current > VOLT_MAX)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MAX)
	    fix_bounds_bug(freqs, reals, apps, out)
	  # Goes down from above MAX to middle
	  elseif (prev > VOLT_MAX && VOLT_MIN < current < VOLT_MAX)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MAX)
	    fix_bounds_bug(freqs, reals, apps, out)
	    volt_safe = true
	  # Goes down from middle below MIN
	  elseif (VOLT_MIN < prev < VOLT_MAX && current < VOLT_MIN)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MIN)
	    fix_bounds_bug(freqs, reals, apps, out)
	  # Goes up from below MIN to middle
	  elseif (prev < VOLT_MIN && VOLT_MIN < current < VOLT_MAX)
	    interpolate_points(times, volts, volts_bounds, out.volt, time, VOLT_MIN)
	    fix_bounds_bug(freqs, reals, apps, out)
	    volt_safe = true
	  elseif (VOLT_MIN < current < VOLT_MAX)
	    volt_safe = true
	  end
	  # Current point is in middle
	elseif (VOLT_MIN < current < VOLT_MAX)
	  volt_safe = true
	end

        push!(timestamps, timestamp)
        push!(times, time    )
        push!(volts, out.volt)
	      push!(volts_bounds, volt_safe ? NaN : out.volt)
        push!(freqs, out.freq)
        push!(reals, out.real)
        push!(apps,  out.app )
        push!(recordings, out)

	if (NO_GUI)
		println("$timestamp ($time): Volts=$(out.volt), Freq=$(out.freq), Pow-Real=$(out.real), Pow-App=$(out.app)")
	end

	iter_count += 1
        global spin_lock = true
      end
    end
    close(t)
    global NO_CSV
    if (!NO_CSV)
      csv_data = DataFrame("Timestamp"      => timestamps,
			   "Runtime"        => times,
			   "Voltage [V]" => volts,
                           "Frequencies"    => freqs,
                           "Power_Real"     => reals,
			   "Power_Apparent" => apps
                          )
      global csv_name
      CSV.write(csv_name, csv_data)
    end
    print("Recordings done. Press [Enter] to close.")
    readline()
  end
catch e
  println(e)
end

RM.close()

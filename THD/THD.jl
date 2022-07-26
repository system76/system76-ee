# Total Harmonic Distortion Calculator
convert_to_float(str) = parse(Float64, str)
square(num) = num^2

print("Fundemental Voltage: ")
v_fund = convert_to_float(readline())
print("List of voltage harmonics: ")
v_harm = sqrt(reduce(+, square.(convert_to_float.(split(readline(), " ")))))
println("Total harmonic Distortion: $(round((v_harm / v_fund) * 100, digits = 2))%")

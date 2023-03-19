"""
graph.py
10. March 2023

draw a wonderful graph

Author:
Nilusink
"""
import matplotlib.pyplot as plt


INTERVAL: int = 500  # interval in milliseconds


def read_file() -> tuple[list[float], list[float], list[float]]:
    """
    read the "csv" file
    """
    out = ([], [], [])
    with open("cpu_stats.csv", "r") as f:
        for line in f.readlines():
            voltage, temperature, clock = [float(val) for val in line.split(";")]

            out[0].append(voltage)
            out[1].append(temperature)
            out[2].append(clock)

    return out


voltages, temperatures, clocks = read_file()


plt.plot(list(range(len(voltages))), voltages)

plt.show()
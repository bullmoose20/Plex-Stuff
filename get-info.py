import psutil
import time
import platform
import cpuinfo

# Get system information
os_name = platform.system()
os_release = platform.release()
os_version = platform.version()
cpu_info = cpuinfo.get_cpu_info()

print(f"Running on {os_name} {os_release} {os_version}")
print(f"CPU: {cpu_info['brand_raw']}, {cpu_info['arch']} architecture, {psutil.cpu_count()} CPUs")

cpu_percent_list = []
memory_list = []
disk_usage_list = []
net_io_counters_list = []
load_avg_list = []

# Run the script for 10 seconds
for i in range(120):
    cpu_percent = psutil.cpu_percent()
    memory = psutil.virtual_memory()
    disk_usage = psutil.disk_usage('/')
    net_io_counters = psutil.net_io_counters()
    load_avg = psutil.getloadavg()

    print(f"CPU usage: {cpu_percent}%, RAM usage: {memory.percent}%, "
          f"RAM used: {memory.used} bytes, RAM available: {memory.available} bytes, "
          f"Disk usage: {disk_usage.used} bytes used, {disk_usage.total} bytes total, "
          f"Net IO Counters: {net_io_counters}, Load Average: {load_avg}")

    cpu_percent_list.append(cpu_percent)
    memory_list.append((memory.percent, memory))
    disk_usage_list.append(disk_usage.used)
    net_io_counters_list.append(net_io_counters)
    load_avg_list.append(load_avg)

    time.sleep(1)

# Calculate min, max, and average CPU usage, RAM usage, Disk usage, and Load Average
min_cpu = min(cpu_percent_list)
max_cpu = max(cpu_percent_list)
avg_cpu = sum(cpu_percent_list) / len(cpu_percent_list)

min_memory_percent = min(memory[0] for memory in memory_list)
max_memory_percent = max(memory[0] for memory in memory_list)
avg_memory_percent = sum(memory[0] for memory in memory_list) / len(memory_list)

min_memory_bytes = min(memory[1].used for memory in memory_list)
max_memory_bytes = max(memory[1].used for memory in memory_list)
avg_memory_bytes = sum(memory[1].used for memory in memory_list) / len(memory_list)

min_disk_usage = min(disk_usage_list)
max_disk_usage = max(disk_usage_list)
avg_disk_usage = sum(disk_usage_list) / len(disk_usage_list)

min_load_avg = min(load_avg[0] for load_avg in load_avg_list)
max_load_avg = max(load_avg[0] for load_avg in load_avg_list)
avg_load_avg = sum(load_avg[0] for load_avg in load_avg_list) / len(load_avg_list)

print(f"Min CPU usage: {min_cpu}%, Max CPU usage: {max_cpu}%, Avg CPU usage: {avg_cpu}%")
print(
    f"Min RAM usage: {min_memory_percent}%, Max RAM usage: {max_memory_percent}%, Avg RAM usage: {avg_memory_percent}%, "
    f"Min RAM used: {min_memory_bytes} bytes, Max RAM used: {max_memory_bytes} bytes, Avg RAM used: {avg_memory_bytes} bytes")
print(f"Min Disk usage: {min_disk_usage} bytes used, Max Disk usage: {max_disk_usage} bytes used, Avg Disk usage: {avg_disk_usage} bytes used")
print(f"Min Load Average: {min_load_avg}, Max Load Average: {max_load_avg}, Avg Load Average: {avg_load_avg}")

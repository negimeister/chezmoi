BIND_PID1="1002 15de"
BIND_BDF1="0000:05:00.1"

BIND_PID2="1022 15df"
BIND_BDF2="0000:05:00.2"

BIND_PID3="1022 15e0"
BIND_BDF3="0000:05:00.3"

BIND_PID4="1022 15e1"
BIND_BDF4="0000:05:00.4"

BIND_PID5="1022 15e2"
BIND_BDF5="0000:05:00.5"

BIND_PID6="1022 15e3"
BIND_BDF6="0000:05:00.6"


sudo modprobe vfio-pci
echo "$BIND_PID1" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$BIND_BDF1" > /sys/bus/pci/devices/$BIND_BDF1/driver/unbind
echo "$BIND_BDF1" > /sys/bus/pci/drivers/vfio-pci/bind
echo "$BIND_PID1" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo "$BIND_PID2" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$BIND_BDF2" > /sys/bus/pci/devices/$BIND_BDF2/driver/unbind
echo "$BIND_BDF2" > /sys/bus/pci/drivers/vfio-pci/bind
echo "$BIND_PID2" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo "$BIND_PID3" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$BIND_BDF3" > /sys/bus/pci/devices/$BIND_BDF3/driver/unbind
echo "$BIND_BDF3" > /sys/bus/pci/drivers/vfio-pci/bind
echo "$BIND_PID3" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo "$BIND_PID4" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$BIND_BDF4" > /sys/bus/pci/devices/$BIND_BDF4/driver/unbind
echo "$BIND_BDF4" > /sys/bus/pci/drivers/vfio-pci/bind
echo "$BIND_PID4" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo "$BIND_PID5" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$BIND_BDF5" > /sys/bus/pci/devices/$BIND_BDF5/driver/unbind
echo "$BIND_BDF5" > /sys/bus/pci/drivers/vfio-pci/bind
echo "$BIND_PID5" > /sys/bus/pci/drivers/vfio-pci/remove_id

echo "$BIND_PID6" > /sys/bus/pci/drivers/vfio-pci/new_id
echo "$BIND_BDF6" > /sys/bus/pci/devices/$BIND_BDF6/driver/unbind
echo "$BIND_BDF6" > /sys/bus/pci/drivers/vfio-pci/bind
echo "$BIND_PID6" > /sys/bus/pci/drivers/vfio-pci/remove_id

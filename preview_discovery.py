import sys
sys.path.insert(0, '/tmp')
import sensors_new as s
m = s.SensorManager()
m.discover()
for x in m.sensors:
    print(x.id, '|', x.label)
m.read_all()
print('--- read_all ---')
for x in m.sensors:
    print(x.id, '=', x.value, 'err:', x.error)

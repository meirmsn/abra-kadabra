# Does MLX get a Metal GPU here, and how does a matmul compare on CPU and GPU?
import time
import mlx.core as mx

print("MLX: version", mx.__version__, "metal available", mx.metal.is_available())
print("MLX: default device", mx.default_device())
try:
    print("MLX: device info", mx.metal.device_info())
except Exception as e:  # the API moved between versions
    print("MLX: device info unavailable", e)
a = mx.random.normal((2048, 2048))
b = mx.random.normal((2048, 2048))
for dev in (mx.cpu, mx.gpu):
    try:
        mx.eval(mx.matmul(a, b, stream=dev))
        t0 = time.time()
        for _ in range(20):
            mx.eval(mx.matmul(a, b, stream=dev))
        dt = time.time() - t0
        print(f"MLX: {dev} 20 matmuls 2048^2 {dt*1000:.0f} ms ({20*2*2048**3/dt/1e9:.0f} GFLOP/s)")
    except Exception as e:
        print("MLX:", dev, "error", e)

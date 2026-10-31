# A tiny Core ML ML Program (8 linear+relu layers, fp16) to see which compute units run it.
import sys
import numpy as np
import coremltools as ct
from coremltools.converters.mil import Builder as mb

rng = np.random.default_rng(0)
W = [(rng.standard_normal((512, 512)) * 0.01).astype(np.float32) for _ in range(8)]


@mb.program(input_specs=[mb.TensorSpec(shape=(1, 512))])
def prog(x):
    for w in W:
        x = mb.relu(x=mb.linear(x=x, weight=w))
    return x


m = ct.convert(prog, convert_to="mlprogram", compute_precision=ct.precision.FLOAT16,
               minimum_deployment_target=ct.target.macOS14)
m.save(sys.argv[1])
print("COREML: saved", sys.argv[1], "coremltools", ct.__version__)

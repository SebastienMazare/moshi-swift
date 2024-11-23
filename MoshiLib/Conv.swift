// Copyright (c) Kyutai, all rights reserved.
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

import MLX
import MLXFast
import MLXNN
import MLXRandom

// Conv1d + dilation
class Conv1d: Module, UnaryLayer {
    let weight: MLXArray
    let bias: MLXArray?
    let padding: Int
    let groups: Int
    let stride: Int
    let dilation: Int

    init(
        inputChannels: Int,
        outputChannels: Int,
        kernelSize: Int,
        stride: Int = 1,
        padding: Int = 0,
        groups: Int = 1,
        dilation: Int = 1,
        bias: Bool = true
    ) {
        let scale = sqrt(1 / Float(inputChannels * kernelSize))

        self.weight = uniform(
            low: -scale, high: scale, [outputChannels, kernelSize, inputChannels / groups])
        self.bias = bias ? MLXArray.zeros([outputChannels]) : nil
        self.padding = padding
        self.groups = groups
        self.stride = stride
        self.dilation = dilation
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        var y = conv1d(
            x, weight, stride: stride, padding: padding, dilation: dilation, groups: groups)
        if let bias {
            y = y + bias
        }
        return y
    }
}

// ConvTranspose1d + groups
class ConvTransposed1d: Module, UnaryLayer {

    let weight: MLXArray
    let bias: MLXArray?
    let padding: Int
    let stride: Int
    let groups: Int

    init(
        inputChannels: Int,
        outputChannels: Int,
        kernelSize: Int,
        stride: Int = 1,
        padding: Int = 0,
        groups: Int = 1,
        bias: Bool = true
    ) {
        let scale = sqrt(1 / Float(inputChannels * kernelSize))

        self.weight = uniform(
            low: -scale, high: scale, [outputChannels, kernelSize, inputChannels])
        self.bias = bias ? MLXArray.zeros([outputChannels]) : nil
        self.padding = padding
        self.stride = stride
        self.groups = groups
    }

    open func callAsFunction(_ x: MLXArray) -> MLXArray {
        var y = convTransposed1d(x, weight, stride: stride, padding: padding, groups: groups)
        if let bias {
            y = y + bias
        }
        return y
    }
}

// TODO: Handle weight-norm either when importing the weights or at runtime.
class NormConv1d: Module, UnaryLayer {
    @ModuleInfo(key: "conv") var conv: Conv1d

    init(
        inC: Int, outC: Int, kSize: Int,
        stride: Int = 1,
        padding: Int = 0,
        groups: Int = 1,
        dilation: Int = 1,
        bias: Bool = true
    ) {
        self._conv.wrappedValue = Conv1d(
            inputChannels: inC, outputChannels: outC, kernelSize: kSize, stride: stride,
            padding: padding,
            groups: groups, dilation: dilation, bias: bias)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        self.conv(x)
    }
}

class NormConvTranspose1d: Module, UnaryLayer {
    @ModuleInfo(key: "convtr") var convtr: ConvTransposed1d

    init(
        inC: Int, outC: Int, kSize: Int,
        stride: Int = 1,
        padding: Int = 0,
        groups: Int = 1,
        bias: Bool = true
    ) {
        self._convtr.wrappedValue = ConvTransposed1d(
            inputChannels: inC, outputChannels: outC, kernelSize: kSize, stride: stride,
            padding: padding, groups: groups, bias: bias)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        self.convtr(x)
    }
}

func getExtraPaddingForConv1d(_ x: MLXArray, kSize: Int, stride: Int, paddingTotal: Int) -> Int {
    let len = x.dim(-1)
    let nFrames = Float(max(len + paddingTotal - kSize, 0)) / Float(stride) + 1.0
    let idealLen = (Int(nFrames.rounded(.up)) - 1) * stride + kSize - paddingTotal
    return max(0, idealLen - len)
}

func unpad1d(_ x: MLXArray, unpadL: Int, unpadR: Int) -> MLXArray {
    let len = x.dim(-1)
    let left = unpadL
    let right = len - unpadR
    return x[.ellipsis, left..<right]
}

class StreamableConv1d: Module, UnaryLayer, StreamingLayer {
    let padMode: PadMode
    let causal: Bool
    let kSize: Int
    var leftPadApplied: Bool = false
    var statePrevXs: StreamArray = StreamArray()
    @ModuleInfo(key: "conv") var conv: NormConv1d

    init(
        inC: Int, outC: Int, kSize: Int, stride: Int, dilation: Int, groups: Int, bias: Bool,
        causal: Bool, padMode: PadMode
    ) {
        self.causal = causal
        self.padMode = padMode
        self.kSize = kSize
        self._conv.wrappedValue = NormConv1d(
            inC: inC, outC: outC, kSize: kSize, groups: groups, dilation: dilation, bias: bias)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        var kSize = self.kSize
        // Effective kernel size with dilations.
        kSize = (kSize - 1) * self.conv.conv.dilation + 1
        let paddingTotal = kSize - self.conv.conv.stride
        let extraPadding = getExtraPaddingForConv1d(
            x, kSize: kSize, stride: self.conv.conv.stride, paddingTotal: paddingTotal)
        var pd: MLXArray
        if self.causal {
            pd = padded(x, width: IntOrPair((paddingTotal, extraPadding)), mode: self.padMode)
        } else {
            let paddingRight = paddingTotal / 2
            let paddingLeft = paddingTotal - paddingRight
            pd = padded(
                x, width: IntOrPair((paddingLeft, paddingRight + extraPadding)), mode: self.padMode)
        }
        return self.conv(pd)
    }

    func resetState() {
        statePrevXs = StreamArray()
        self.leftPadApplied = false
    }

    func step(_ x: StreamArray) -> StreamArray {
        if let inner = x.inner {
            if self.leftPadApplied {
            }
            let stride = self.conv.conv.stride
            let dilation = self.conv.conv.dilation
            let kernel = (self.kSize - 1) * dilation + 1
            var x = StreamArray(inner)
            x = self.statePrevXs.cat2(x, axis: -1)
            let seqLen = x.dim(-1)
            let numFrames = max(seqLen + stride - kernel, 0) / stride
            if numFrames > 0 {
                let offset = numFrames * stride
                self.statePrevXs = x.narrow(offset, seqLen - offset, axis: -1)
                let inL = (numFrames - 1) * stride + kernel
                x = x.narrow(0, inL, axis: -1)
                if let x = x.inner {
                    return StreamArray(self.conv.conv(x))
                } else {
                    return StreamArray()
                }
            } else {
                self.statePrevXs = x
                return StreamArray()
            }
        } else {
            return StreamArray()
        }
    }
}

class StreamableConvTranspose1d: Module, UnaryLayer, StreamingLayer {
    let causal: Bool
    let kSize: Int
    var statePrevYs: StreamArray = StreamArray()
    @ModuleInfo(key: "convtr") var convtr: NormConvTranspose1d

    init(
        inC: Int, outC: Int, kSize: Int, stride: Int, groups: Int, bias: Bool,
        causal: Bool
    ) {
        self.causal = causal
        self.kSize = kSize
        self._convtr.wrappedValue = NormConvTranspose1d(
            inC: inC, outC: outC, kSize: kSize, groups: groups, bias: bias)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        let stride = self.convtr.convtr.stride
        let paddingTotal = max(self.kSize - stride, 0)
        let x = self.convtr(x)
        if self.causal {
            return unpad1d(x, unpadL: 0, unpadR: paddingTotal)
        } else {
            let unpadR = paddingTotal / 2
            let unpadL = paddingTotal - unpadR
            return unpad1d(x, unpadL: unpadL, unpadR: unpadR)
        }
    }

    func resetState() {
        statePrevYs = StreamArray()
    }

    func step(_ x: StreamArray) -> StreamArray {
        if let x = x.inner {
            let stride = self.convtr.convtr.stride
            var ys = self.convtr(x)
            let ot = ys.dim(1)
            if var prevYs = self.statePrevYs.inner {
                let pt = prevYs.dim(-1)
                if let bias = self.convtr.convtr.bias {
                    prevYs = prevYs - bias
                }
                let ys1 = ys[.ellipsis, 0..<pt] + prevYs
                let ys2 = ys[.ellipsis, pt...]
                ys = concatenated([ys1, ys2], axis: -1)
            }
            let invalidSteps = self.kSize - stride
            let (ys_, prevYs) = StreamArray(ys).split(lhsLen: ot - invalidSteps, axis: -1)
            self.statePrevYs = prevYs
            return ys_
        } else {
            return StreamArray()
        }
    }
}

class ConvDownsample1d: Module, UnaryLayer, StreamingLayer {
    @ModuleInfo(key: "conv") var conv: StreamableConv1d

    init(stride: Int, dim: Int, causal: Bool) {
        self._conv.wrappedValue = StreamableConv1d(
            inC: dim, outC: dim, kSize: 2 * stride, stride: stride, dilation: 1, groups: 1,
            bias: false, causal: causal, padMode: .edge)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        self.conv(x)
    }

    func resetState() {
        self.conv.resetState()
    }

    func step(_ x: StreamArray) -> StreamArray {
        self.conv.step(x)
    }
}

class ConvTrUpsample1d: Module, UnaryLayer {
    @ModuleInfo(key: "convtr") var convtr: StreamableConvTranspose1d

    init(stride: Int, dim: Int, causal: Bool) {
        self._convtr.wrappedValue = StreamableConvTranspose1d(
            inC: dim, outC: dim, kSize: 2 * stride, stride: stride, groups: dim, bias: false,
            causal: causal)
    }

    func callAsFunction(_ x: MLXArray) -> MLXArray {
        self.convtr(x)
    }

    func resetState() {
        self.convtr.resetState()
    }

    func step(_ x: StreamArray) -> StreamArray {
        self.convtr.step(x)
    }
}
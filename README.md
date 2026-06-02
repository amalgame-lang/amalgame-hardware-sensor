# amalgame-hardware-sensor

Portable **sensor drivers** for Amalgame over [`amalgame-hal`](https://github.com/amalgame-lang/amalgame-hal): ultrasonic distance, SPI ADC (the Pi has none), and the BME280 environment sensor (weather stations, drone altimetry). One driver, runs on Raspberry Pi and future MCU backends.

```sh
amc package add hardware-sensor
```

```amalgame
import Amalgame.Hardware          // GpioOut/In, Spi, I2c, SysClock (Pi)
import Amalgame.Hardware.Sensor

let dist = new Hcsr04(new GpioOut(23), new GpioIn(24), new SysClock())
let cm   = dist.ReadCm()

let adc  = new Mcp3008(new Spi(0,0))
let raw  = adc.Read(0)            // 0..1023

let env  = new Bme280(new I2c(1), 0x76)
env.Read()
let tC   = env.TempCenti()        // °C ×100
```

| Class | API |
|---|---|
| `Hcsr04(trig: DigitalOut, echo: DigitalIn, clk: Clock)` | `ReadCm()` → cm (-1 on timeout) |
| `Mcp3008(spi: SpiBus)` | `Read(ch 0..7)` → 0..1023 |
| `Bme280(bus: I2cBus, addr)` | `Read()`, `TempCenti()`, `PressurePa()`, `HumidityMilli()`, `IsPresent()` |

Requires amc ≥ 0.8.72. Apache-2.0.

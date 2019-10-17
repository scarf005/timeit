import times, stats, math
import strformat
import std/monotimes
import macros


export times 


const 
  repeatTimes = 7
  loopTimes = 0

type
  TimeInt* = int
  Timer* = ref object
    name: string
    mean: float
    std: float
    times: int
    loops: int
  Moment = ref object
    minutes: TimeInt
    seconds: TimeInt
    milliSeconds: TimeInt
    microSeconds: TimeInt
    nanoSeconds: float


proc `$`*(moment: Moment): string
proc `$`*(timer: Timer): string
proc toTime(time: float): Moment



proc `$`*(moment: Moment): string = 
  result &= "["
  if moment.minutes != 0:
    result &= fmt"{moment.minutes}m "
  if moment.seconds != 0:
    result &= fmt"{moment.seconds}s "
  if moment.milliSeconds != 0:
    result &= fmt"{moment.milliSeconds}ms "
  if moment.microSeconds != 0:
    result &= fmt"{moment.microSeconds}μs "
  result &= fmt"{moment.nanoSeconds:.2f}ns"
  result &= "]"

  

proc `$`*(timer: Timer): string = 
  let momentMean = toTime(timer.mean)
  let momentStd = toTime(timer.std)
  fmt"{momentMean} ± {momentStd} per loop (mean ± std. dev. of {timer.times} runs, {timer.loops} loops each)"


proc toTime(time: float): Moment = 
  var moment = new Moment
  let nanoTime = TimeInt(time)
  moment.nanoSeconds = float(nanoTime mod 1_000 - nanoTime) + time 
  moment.microSeconds = (nanoTime div 1_000) mod 1_000
  moment.milliSeconds = (nanoTime div 1_000_000) mod 1_000
  moment.seconds = (nanoTime div 1_000_000_000) mod 1_000
  moment.minutes = (nanoTime div 1_000_000_000 div 60) mod 1_000
  moment



# 8.26 ns ± 0.12 ns per loop (mean ± std. dev. of 7 runs, 100000000 loops each)
#  TODO  
# Modify to get the info of proc
template inner*(myFunc: untyped): TimeInt = 
  let time = getMonoTime()
  myFunc
  let lasting = getMonoTime() - time
  lasting.inNanoseconds.TimeInt


template timeGo*(myFunc: untyped, 
                repeatTimes: int = repeatTimes, 
                loopTimes: int = loopTimes): Timer = 
  var 
    timer = new Timer
    timerTotal: seq[TimeInt]
    totalMean: seq[float]
    totalStd: seq[float]
    timerTimes: int = repeatTimes
    timerLoops: TimeInt = loopTimes
  assert timerTimes >= 1, "repeatTimes must be greater than 1"
  var oneTime = inner(myFunc)
  let singleTime = oneTime.float
  if oneTime != 0:
    timerLoops = 1_000_000_000 div oneTime
    if timerLoops == 0:
      # if cost time > 5s,  stop timeGo.
      oneTime = oneTime div 50_000
      oneTime = oneTime div 100_000
      if oneTime != 0:
          timerTimes = 0
          totalMean.add(singleTime)
          totalStd.add(0.0)
      timerLoops = 1
    else:
      timerLoops = 10 ^ int(log10(timerLoops.float))
  else:
    totalMean.add(0.5)
    totalStd.add(0)
    timerTimes = 0
    timerLoops = 1
  if loopTimes != 0:
    timerLoops = loopTimes
  for _ in 1 .. timerTimes:
    for _ in 1 .. timerLoops:
      timerTotal.add inner(myFunc)
    totalMean.add timerTotal.mean
    totalStd.add timerTotal.standardDeviation
    GC_full_collect()




  timer.mean = totalMean.mean
  timer.std = totalStd.standardDeviation
  if timerTimes == 0:
    timerTimes = 1
  timer.times = timerTimes
  timer.loops = timerLoops
  timer
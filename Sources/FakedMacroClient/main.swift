import FakedMacro

let a = 17
let b = 25

@Faked(types: ["X": Int.self])
protocol Thing {
  associatedtype X
  func intFunc() -> Int
}

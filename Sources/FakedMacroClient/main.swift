import FakedMacro

let a = 17
let b = 25

@Faked protocol Parent {
  var x: Int { get }
}

@Faked(inherit: [EmptyParent.self]) protocol Child: Parent {
  var y: Int { get }
}

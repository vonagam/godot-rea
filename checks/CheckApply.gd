extends Control

const LabelScene := preload('Label.tscn')


var element: rea.NodeElement = null
var count: int = 0
var delta: float = 0.0


func _process(delta: float) -> void:
  self.delta += delta
  while self.delta >= 1.0:
    self.count += 1
    self.delta -= 1
    if self.count == 1:
      self.element = rea.apply(null, get_descriptor())
    elif self.count < 4:
      self.element = rea.apply(self.element, get_descriptor())
    else:
      self.element = rea.apply(self.element, null)
      self.count = 0


func get_descriptor() -> rea.NodeDescriptor:
  return (rea.node(self)
    .persistent()
    .children([
      (rea.scene(LabelScene)
        .prop(&'text', 'Apply: %d' % count)
      ),
    ])
  )

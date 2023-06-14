extends ColorRect


class Context extends rea.Context:
  static func get_fallback() -> Variant:
    return rea.ignore


@export var default_color := Color(0, 0.75, 0)


func _init() -> void:
  rea.component.init(self, self.render)

func _notification(what: int) -> void:
  rea.component.notify(self, what)


func render(arg: rea.Arg) -> rea.NodeDescriptor:
  var label: Variant = rea.use.context(Context)

  var initial_nodes: rea.Descriptor = rea.use.memo(func():
    return rea.nodes().nodes(self.get_children())
  )

  return (rea.node(self)
    .arg(arg)
    .prop(&'color', arg.props.get(&'color', self.default_color))
    .children([initial_nodes, arg.children])
    .portals([rea.path(^'label').nullable().prop(&'text', label)])
  )

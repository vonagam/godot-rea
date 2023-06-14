extends rea.Component

const Component := preload('Component.gd')


func render(arg: rea.Arg) -> rea.NodeDescriptor:
  var control_ref := rea.use.ref()

  rea.use.effect(func () -> void:
    var control: Control = control_ref.current
    control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  )

  var children: Array[rea.Descriptor] = rea.use.memo(func () -> Array[rea.Descriptor]:
    return [
      (rea.type(Label)
        .props({
          &'horizontal_alignment': HORIZONTAL_ALIGNMENT_CENTER,
          &'vertical_alignment': VERTICAL_ALIGNMENT_CENTER,
          &'anchor_right': 1,
          &'anchor_bottom': 1,
          &'text': 'Type',
        })
      ),
    ]
  )

  return (rea.node(self)
    .children([
      (rea.type(Component)
        .ref(control_ref.update)
        .rendered()
        .prop(&'color', Color(0, 0.5, 0.5))
        .children(children)
      ),
    ])
  )

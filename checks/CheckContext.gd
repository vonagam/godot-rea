extends rea.Component

const ComponentScene := preload('Component.tscn')
const Component := preload('Component.gd')


func render(arg: rea.Arg) -> rea.NodeDescriptor:
  return (rea.node(self)
    .children([
      (rea.context(Component.Context, 'Context')
        .children([
          (rea.scene(ComponentScene)
            .rendered()
          ),
        ])
      ),
    ])
  )

class_name rea extends 'Utils.gd'


const Descriptor := preload( 'Internal.gd' ).Descriptor
const Element := preload( 'Internal.gd' ).Element

const Arg := preload( 'Internal.gd' ).RenderArg
const Context := preload( 'Internal.gd' ).RenderContext
const Component := preload( 'Internal.gd' ).RenderComponent

const NodeDescriptor := preload( 'Internal.gd' ).NodeDescriptor
const NodeElement := preload( 'Internal.gd' ).NodeElement

const PathDescriptor := preload( 'Internal.gd' ).PathDescriptor
const TypeDescriptor := preload( 'Internal.gd' ).TypeDescriptor
const SceneDescriptor := preload( 'Internal.gd' ).SceneDescriptor
const NodesDescriptor := preload( 'Internal.gd' ).NodesDescriptor
const CallableDescriptor := preload( 'Internal.gd' ).CallableDescriptor
const FragmentDescriptor := preload( 'Internal.gd' ).FragmentDescriptor
const ContextDescriptor := preload( 'Internal.gd' ).ContextDescriptor

const component := preload( 'Internal.gd' ).component
const use := preload( 'Hooks.gd' ).use


static func node( node: Node ) -> NodeDescriptor:
  return NodeDescriptor.new( node )

static func path( path: NodePath, node: Node = null ) -> PathDescriptor:
  return PathDescriptor.new( path, node )

static func type( type: Variant, script: GDScript = null ) -> TypeDescriptor:
  return TypeDescriptor.new( type, script )

static func scene( scene: PackedScene ) -> SceneDescriptor:
  return SceneDescriptor.new( scene )

static func nodes() -> NodesDescriptor:
  return NodesDescriptor.new()

static func callable( callable: Callable ) -> CallableDescriptor:
  return CallableDescriptor.new( callable )

static func fragment() -> FragmentDescriptor:
  return FragmentDescriptor.new()

static func context( context: GDScript, value: Variant ) -> ContextDescriptor:
  return ContextDescriptor.new( context, value )


static func apply( element: NodeElement, descriptor: NodeDescriptor ) -> NodeElement:
  if element == null && descriptor == null: return null

  if descriptor == null:
    element._removed()
    return null

  if element != null:
    if is_same( element.descriptor._key, descriptor._key ) && element.descriptor._is_compatible( descriptor ):
      element.update_descriptor( descriptor )
      return element
    element._removed()

  element = descriptor._make_element( null, false )
  element.update_descriptor( descriptor )
  return element

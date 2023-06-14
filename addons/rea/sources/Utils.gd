const noop := Callable()
const ignore := &'__rea_ignore__'


static func is_ignore(value: Variant) -> bool:
  return is_same(value, ignore)

package interpreter

main :: proc() {
	s := "++<+[++]"
	parser(transmute([]u8)s)
}

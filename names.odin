package history

import "core:strings"
import "core:math/rand"

vowels := [?]u8{'a', 'e', 'i', 'o', 'u'}
consonants := [?]u8{'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'y', 'z'}

generate_name :: proc(syllables_count:int, allocator:=context.temp_allocator) -> string
{
	structures := [?]string{"CVC", "CV", "VC", "V"}
	builder := strings.builder_make(context.temp_allocator)
	for _ in 0..<syllables_count {
		structure := rand.choice(structures[:])
		for c in structure {
			if c == 'C' {
				strings.write_byte(&builder, rand.choice(consonants[:]))
			} else {
				strings.write_byte(&builder, rand.choice(vowels[:]))
			}
		}
	}

	ret := strings.to_string(builder)
	return strings.to_pascal_case(ret, allocator)
}

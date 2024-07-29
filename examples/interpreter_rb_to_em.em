## Let this serve as
## def t code, &block; end
#
#
#x { in -> in }
#x(123)
#
#
##
##
#
#1
#
#
#-1
#
#
#48.15
#
#
#16.
#
#
#.23
#
#
#2 + 3
#
#
#4 - 5
#
#
#6 * 7
#
#
#8/9
#
#
#10%11
#
#
#-1 + +3
#
#
#(1 + 2) * 3
#
#
#1/2
#
#
#1/2.0
#
#
#1.0/2
#
#
#1.0/2.0
#
#
#true
#
#
#!true
#
#
#false
#
#
#!false
#
#
#true && false
#
#
#true || false
#
#
#x = 1
#
#
#:lost
#
#
#'lost'
#
#
#'lost' == :lost
#
#
#:lost == :lost
#
#
#'lost' == 'lost'
#
#
#a = 1 + 2
#
#
#{ b = 8 }
#
#
#b = 7
#b
#
#
#
#
#a = 4815
#b = a
#
#b = nil
#
#
#1, nil, 3
#
#
#'b in a string', b, 4+2, nil
#
#
#'`b` interpolated into the string'
#
#
#x = 'the island'
#
#
##{ a = 4 + 8, x, y = 1, z = "2" -> true } # anon blocks cannot have params
#
#
#
#func { -> 4 }
#func2 { -> 6 }
#func() + func2()
#
#
#
#func { -> 1 }
#
#
#0..87
#
#
#1.<10
#
#
## abc?def
##
#
## abc!def
##
#
## abc:def
##
#
#f { x = 3 -> x*3 }
#f()
#
#
#f { x = 3 -> x*3 }
#f(4)
#
#
#x { asd -> asd }
#x(123)
#
#
#x { ert = nil -> ert }
#x()
#
#
#x { hjk = 1 -> hjk }
#x()
#
#
#x = nil
#f { poui -> poui || x }
#f('needs an arg')
#
#
#
#x = 3
#f { welk -> welk || x }
#f('another')
#
#
#
#x = 3
#f { kewr -> kewr || x }
#f(4)
#
#
#
#SOME_CONSTANT = 420
#
#
#Random {}
#Random
#
#{ x = 4 }
#
#
#{ x: 4 }
#
#
#{ x = { y = 48} }
#
#
#Random {}
#Random.new
#
#
#
#x=1
#if x > 2 {
#    "yep"
#else
#    "nope"
#}
#
#
#
#x=1
#if x == 1 {
#    "yep"
#elsif x == 2
#    "boo"
#else
#    "nope"
#}
#
#
#
#x=2
#y = if x == 1 {
#    "yep"
#elsif x == 2
#    "boo"
#else
#    "nope"
#}
#y
#
#
#
#x=2
#z = 4
#y = if x == 1 {
#    "yep"
#elsif x == 2
#    if z == 4 { 1234 else 5678 }
#else
#    "nope"
#}
#y
#
#
#
#x=2
#z = 3
#y = if x == 1 {
#    "yep"
#elsif x == 2
#    if z == 4 { 1234 else 5678 }
#else
#    "nope"
#}
#y
#
#
#
#x=1
#if x == 4 { "no" elsif x == 2 "maybe" else "yes" }
#
#
#
#
#x = 1
#while x < 4 {
#    x = x + 1
#elswhile x < 6
#    x = x + 2
#else
#    9
#}
#
#x + 1
#
#
#
#
#Boo {
#    id =;
#    boo! { -> "boo!" }
#}
#
#Moo {
#    > Boo
#}
#
#Moo.new
#
#
#
#
#Boo {
#    id =;
#    boo! { -> "boo!" }
#}
#
#Moo > Boo {
#}
#
#Moo.new
#
#
#
#Boo {
#    bwah = "boo0!"
#}
#
#scare { %boo ->
##    bwah
#}
#
#b = Boo.new
#scare(b)
#
#    # todo
#
#

#Boo {
#    scream { length = 6 ->
#        phrase = "b"
#        i = 0
#        while i < length {
#            phrase = phrase + "o"
#            i = i + 1
#        }
#        phrase
#    }
#}
#
#go_boo { %boo ->
#	scream()
#}
#
#b = Boo.new
#go_boo(b)

#
#Boo {
#    scary = 1234
#}
#
#moo { boo -> boo.scary }
#first = moo(Boo.new)
#
#moo_with_comp { %boo_param ->
#    scary
#}
#moo_with_comp(Boo.new) + moo_with_comp(b = Boo.new)
#
#    # todo
#
#
#
# Boo {
#     scream { ->
#         "Boo!"
#     }
# }
#
#scare = Boo.new.scream
#scare()
#
#     # todo
#
#
#Dog {
#    bark -> "woof"
#}
#
#
#Dog {
#    bark -> "woof"
#}
#Dog.new.bark
#
#    # todo
#
#
#Dog {
#    bark -> "woof"
#}
#Dog.new.bark()
#
#    # todo
#

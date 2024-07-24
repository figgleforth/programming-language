Ball {
	bounces = 0
	bounce { -> bounces += 1 }
}

puck = Ball.new

serve { &ball ->
	bounce()

}

serve(puck)

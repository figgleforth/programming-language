obj Hatch(numbers: float = 48151.62342)

island: Island
coordinates: float2 = (48.15, 16.23)
seconds_until_disaster: float = 108 * 60

def enter_the_numbers!: Disaster?
  island.numbers = <~
end

def @@update
  seconds_until_disaster -= @@delta_time
  if seconds_until_disaster <= 0
    enter_the_numbers!
  end
end

obj Hatch
  time_for_numbers: bool = true
end
# testing a co

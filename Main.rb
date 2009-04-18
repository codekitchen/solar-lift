#!/usr/bin/env ruby

begin
  require 'rubygems'
rescue LoadError
end
require 'gosu'

class Actor
end

class SolarLiftWindow < Gosu::Window
  include Gosu

  attr_reader :objects

  def initialize
    super(800, 600, false)
    @objects = []
  end

  def button_up(butt)
    case butt
    when KbEscape
      close
    end
  end

  def update
    @objects.reject! { |o| o.update == false }
  end

  def draw
    @objects.each { |o| o.draw }
  end
end

$window = SolarLiftWindow.new()
$window.show

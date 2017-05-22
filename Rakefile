#!/usr/bin/env ruby
# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gnucash2bmd/version'
require "bundler/gem_tasks"
task :default => :install

require 'rake/clean'

CLEAN.include FileList['pkg/*.gem']
CLEAN.include FileList['*.csv*']
CLEAN.include FileList['ruby*.tmp']

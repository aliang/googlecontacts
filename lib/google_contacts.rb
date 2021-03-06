$:.unshift File.dirname(__FILE__)
require 'rubygems'
require 'active_support'
require 'active_support/core_ext/hash'
require 'active_support/core_ext/module'
require 'oauth'
require 'nokogiri'

require 'google_contacts/auth'
require 'google_contacts/wrapper'
require 'google_contacts/base'
require 'google_contacts/contact'
require 'google_contacts/group'

require 'google_contacts/proxies/array'
require 'google_contacts/proxies/hash'
require 'google_contacts/proxies/emails'
require 'google_contacts/proxies/tag'

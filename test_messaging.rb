#!/usr/bin/env ruby

# Test script to check message creation functionality
require_relative 'config/environment'

# Find a conversation to test with
conversation = Conversation.first
if conversation.nil?
  puts "No conversations found. Creating one..."
  course_material = CourseMaterial.first
  student = Student.first || Student.create!(name: "Test Student", email: "test@example.com")
  conversation = Conversation.create!(course_material: course_material, student: student)
end

puts "Testing conversation ##{conversation.id}"
puts "Before: #{conversation.messages.count} messages"

# Create a test message
message = conversation.messages.build(content: "Hello, this is a test message", role: "user")

if message.save
  puts "✅ Message created successfully!"
  puts "After: #{conversation.reload.messages.count} messages"
  puts "Message content: #{message.content}"
  puts "Message role: #{message.role}"
else
  puts "❌ Failed to create message"
  puts "Errors: #{message.errors.full_messages}"
end
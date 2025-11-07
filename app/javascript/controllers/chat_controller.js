// Stimulus controller for managing chat interface interactions
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "form", "submitButton"]
  static values = { autoScroll: { type: Boolean, default: true } }
  
  connect() {
    console.log("Chat controller connected")
    this.scrollToBottom()
    
    // Auto-focus input when controller connects
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
    
    // Listen for new messages to auto-scroll
    this.element.addEventListener("turbo:before-stream-render", this.beforeStreamRender.bind(this))
    
    // Debug Turbo events
    this.element.addEventListener("turbo:submit-start", (event) => {
      console.log("Turbo submit start:", event.detail)
    })
    
    this.element.addEventListener("turbo:submit-end", (event) => {
      console.log("Turbo submit end:", event.detail)
    })
    
    this.element.addEventListener("turbo:before-fetch-request", (event) => {
      console.log("Turbo before fetch request:", event.detail)
    })
    
    this.element.addEventListener("turbo:before-fetch-response", (event) => {
      console.log("Turbo before fetch response:", event.detail)
    })
  }
  
  disconnect() {
    this.element.removeEventListener("turbo:before-stream-render", this.beforeStreamRender.bind(this))
  }
  
  // Handle form submission
  submit(event) {
    console.log("Chat controller: Form submission intercepted", event)
    console.log("Event target:", event.target)
    
    const content = this.inputTarget.value.trim()
    
    if (!content) {
      console.log("Chat controller: Preventing empty submission")
      event.preventDefault()
      return
    }
    
    console.log("Chat controller: Submitting message:", content)
    
    // Disable submit button to prevent double submission
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = "Sending..."
    }
  }
  
  // Handle input changes
  inputChanged() {
    const hasContent = this.inputTarget.value.trim().length > 0
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !hasContent
    }
  }
  
  // Handle enter key for submission
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      
      if (this.inputTarget.value.trim()) {
        this.formTarget.requestSubmit()
      }
    }
  }
  
  // Scroll to bottom of messages
  scrollToBottom() {
    if (this.autoScrollValue && this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }
  
  // Handle before stream render to maintain scroll position or auto-scroll
  beforeStreamRender(event) {
    if (this.hasMessagesTarget) {
      const { target } = this.messagesTarget
      const isScrolledToBottom = target.scrollHeight - target.clientHeight <= target.scrollTop + 1
      
      // Auto-scroll if user was already at bottom
      if (isScrolledToBottom) {
        setTimeout(() => this.scrollToBottom(), 0)
      }
    }
  }
  
  // Reset form after successful submission
  reset() {
    console.log("Chat controller: Resetting form after successful submission")
    
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.focus()
    }
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Send"
    }
  }
  
  // Toggle typing indicator visibility
  showTyping() {
    const indicator = this.element.querySelector("[data-typing-indicator]")
    if (indicator) {
      indicator.classList.remove("hidden")
      this.scrollToBottom()
    }
  }
  
  hideTyping() {
    const indicator = this.element.querySelector("[data-typing-indicator]")
    if (indicator) {
      indicator.classList.add("hidden")
    }
  }
}
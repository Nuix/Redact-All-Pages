# Menu Title: Redact All Pages
# Needs Case: true
# Needs Selected Items: false

script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.CustomDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

require 'thread'

# This defines how many threads the script will use.  Note that
# more is not always better!
concurrency = 4

# These variables define redaction region
# Values are provided as fraction of page width / height
# 0.0 = 0%
# 0.5 = 50%
# 0.75 = 75%
# 1.0 = 100%
# etc
#
# redaction_x is percentage from left of page
# redaction_width is percentage further right from redaction_x
# redaction_y is percentage from top of page
# redaction_height = is percentage further down from redaction_y
#
#     (x, y) -------------------------------------- (x + width, y)
#     |                                                          |
#     |                                                          |
#  H  |                                                          |
#  E  |                                                          |
#  I  |                                                          |
#  G  |                                                          |
#  H  |                                                          |
#  T  |                                                          |
#     |                                                          |
#     |                                                          |
#     (x, y + height)--------------------- (x + width, y + height)
#
#                               WIDTH
#
# These values denote the entire page edge to edge
# redaction_x = 0.0
# redaction_width = 1.0
# redaction_y = 0.0
# redaction_height = 1.0
#
# These values would redact the top half of each page
# redaction_x = 0.0
# redaction_width = 1.0
# redaction_y = 0.0
# redaction_height = 0.5
#
# These values would redact the bottom half of each page
# redaction_x = 0.0
# redaction_width = 1.0
# redaction_y = 0.5
# redaction_height = 0.5

redaction_x = 0.0
redaction_width = 1.0
redaction_y = 0.0
redaction_height = 1.0

# Lets perform some quick sanity checks of specified redaction region
if redaction_x < 0.0 || redaction_x > 1.0
	CommonDialogs.showError("'redaction_x' value is invalid (see script source): #{redaction_x}")
end
if redaction_y < 0.0 || redaction_y > 1.0
	CommonDialogs.showError("'redaction_y' value is invalid (see script source): #{redaction_y}")
end
region_right_edge = redaction_x + redaction_width
region_bottom_edge = redaction_y + redaction_height
if region_right_edge > 1.0
	CommonDialogs.showError("redaction_x + redaction_width is greater than 1.0: #{region_right_edge}")
end
if region_bottom_edge > 1.0
	CommonDialogs.showError("redaction_y + redaction_height is greater than 1.0: #{region_bottom_edge}")
end

# Get a list of all the markup set names so user can pick one in settings dialog
markup_set_names = $current_case.getMarkupSets.map{|ms| ms.getName}

# Get a list of all tag names so user can pick one in settings dialog
all_tags = $current_case.getAllTags

# Make sure there is at least 1 tag available to be picked, otherwise tell the user we require this
# and then exit the script immediately
if all_tags.size < 1
	CommonDialogs.showError("This script requires the case to have at least one tag present")
	exit 1
end

# Build the settings dialog
dialog = TabbedCustomDialog.new("Redact All Pages")

# Build the "Settings" tab
main_tab = dialog.addTab("main_tab","Settings")
main_tab.appendSeparator("Markup Settings")
main_tab.appendRadioButton("create_new_markup_set","Create New Markup Set","markup_set_group",true)
main_tab.appendTextField("new_markup_set_name","New Markup Set Name","Redact All Pages #{Time.now.strftime("%Y-%m-%d %H:%H:%S")}")
main_tab.appendTextField("new_markup_set_description","Description","")
main_tab.appendTextField("new_markup_set_reason","Redaction Reason","")
main_tab.enabledOnlyWhenChecked("new_markup_set_name","create_new_markup_set")
main_tab.enabledOnlyWhenChecked("new_markup_set_description","create_new_markup_set")
main_tab.enabledOnlyWhenChecked("new_markup_set_reason","create_new_markup_set")

if markup_set_names.size > 0
	main_tab.appendRadioButton("use_existing_markup_set","Use Existing Markup Set","markup_set_group",false)
	main_tab.appendComboBox("existing_markup_set_name","Markup Set",markup_set_names)
	main_tab.enabledOnlyWhenChecked("existing_markup_set_name","use_existing_markup_set")
end

main_tab.appendSeparator("Target Tag")
main_tab.appendComboBox("tag_name","Tag Name",all_tags)

# Validate user's settings
dialog.validateBeforeClosing do |values|
	if values["create_new_markup_set"]
		# If user specified creating a new markup set, make sure they provided a name for it
		if values["new_markup_set_name"].strip.empty?
			CommonDialogs.showWarning("Please provide a markup set name")
			next false
		end

		# If user specified creating a new markup set, make sure the name does not already exist
		if markup_set_names.any?{|n| n.downcase == values["new_markup_set_name"].downcase}
			CommonDialogs.showWarning("The provided markup set name is already in use in the case")
			next false
		end
	end

	next true
end

# Helper method for escaping particular characters in tag name for query
def escape_tag_for_search(tag)
	return tag
		.gsub("\\","\\\\\\") #Escape \
		.gsub("?","\\?") #Escape ?
		.gsub("*","\\*") #Escape *
		.gsub("\"","\\\"") #Escape "
end

# Display the settings dialog, if everything works out, get to work
dialog.display
if dialog.getDialogResult == true
	# Get settings as hash/map
	values = dialog.toMap

	# Pull settings into variables for convenience
	tag_name = values["tag_name"]
	create_new_markup_set = values["create_new_markup_set"]
	new_markup_set_name = values["new_markup_set_name"]
	new_markup_set_description = values["new_markup_set_description"]
	new_markup_set_reason = values["new_markup_set_reason"]
	use_existing_markup_set = values["use_existing_markup_set"]
	existing_markup_set_name = values["existing_markup_set_name"]

	# Show a progress dialog and do the work
	ProgressDialog.forBlock do |pd|
		puts "Beginning 'Redact All Pages'"
		pd.setTitle("Redact All Pages")
		pd.onMessageLogged do |message|
			puts message
		end

		pd.logMessage("Tag Name: #{tag_name}")
		pd.logMessage("Concurrency: #{concurrency}")

		pd.setMainStatusAndLogIt("Locating tagged items...")
		# Build query for tag that user specified
		query = "tag:\"#{escape_tag_for_search(tag_name)}\""
		pd.logMessage("Query:\n#{query}")

		# Find tagged items in case
		tagged_items = $current_case.search(query)
		pd.logMessage("Located #{tagged_items.size} items")

		# Either create a new markup set or obtain existing one, depending on user settings
		target_markup_set = nil
		if create_new_markup_set
			pd.setMainStatusAndLogIt("Creating new markup set...")
			pd.logMessage("\tName: #{new_markup_set_name}")
			pd.logMessage("\tDescription: #{new_markup_set_description}")
			pd.logMessage("\tRedaction Reason: #{new_markup_set_reason}")
			target_markup_set = $current_case.createMarkupSet(new_markup_set_name,{
				"description" => new_markup_set_description,
				"redactionReason" => new_markup_set_reason,
			})
		else
			pd.setMainStatusAndLogIt("Loading existing markup set...")
			pd.logMessage("\tName: #{existing_markup_set_name}")
			target_markup_set = $current_case.getMarkupSets.select{|ms| ms.getName == existing_markup_set_name}.first
		end

		pd.setMainStatusAndLogIt("Applying redactions...")
		pd.setMainProgress(0,tagged_items.size)
		
		total_pages_redacted = 0
		total_items_processed = 0
		errors = []
		semaphore = Mutex.new
		item_queue = Queue.new

		# Create number of threads based on value in concurrency variable.  Each thread pops items off a thread safe queue.
		# The popped item is then processed.  If a thread pops a nil off the queue, this signals it to shutdown.
		consumers = concurrency.times.map do |i|
			Thread.new do
				thread_id = i+1
				while true
					item = item_queue.pop
					begin
						if item.nil?
							break
						else
							# Here is where we actually apply the redaction:
							# 1. Get PrintedImage for the item
							# 2. Make sure its generated
							# 3. Get the pages
							# 4. For each page, apply redaction based on region defined earlier

							printed_image = item.getPrintedImage
							printed_image.generate
							pages = printed_image.getPages
							if pages.nil? || pages.size < 1
								semaphore.synchronize {
									pd.logMessage("Skipping item without pages: #{item.getGuid}")
								}
								next
							end
							pages.each_with_index do |page,page_index|
								markup = page.createRedaction(target_markup_set,redaction_x,redaction_y,redaction_width,redaction_height)
							end

							# Since we are modifying shared state variables from each thread here, we sychronize access to them
							semaphore.synchronize {
								total_items_processed += 1
								total_pages_redacted += pages.size
								pd.setMainProgress(total_items_processed)
								pd.setMainStatus("Applying redactions (#{total_items_processed}/#{tagged_items.size}), Pages Redacted: #{total_pages_redacted}, Errors: #{errors.size}")
							}
						end
					rescue Exception => exc
						semaphore.synchronize {
							pd.logMessage("Error on thread #{thread_id}: #{exc.message}")
							pd.logMessage("Item may not be fully redacted: "+item.getGuid)
							errors << "Item may not be fully redacted: "+item.getGuid+", due to error on thread #{thread_id}: #{exc.message}"
						}
					end

					if pd.abortWasRequested
						semaphore.synchronize {
							pd.logMessage("Thread #{thread_id} acknowledging abort request")
						}
						break
					end
				end
			end
		end

		# Now that we have built the threads, they should all be waiting for items to enter the Queue

		# Feed our items into the Queue
		tagged_items.each{|item| item_queue.push(item)}

		# Push a nil at the end of the queue for each thread to consume since nil signals to a thread
		# that all the work is completed.
		concurrency.times{|i| item_queue.push(nil)}

		# Join the threads and wait for them to finish doing their work
		consumers.each(&:join)

		# Report some final results
		pd.logMessage("Items Redacted: #{total_items_processed}/#{tagged_items.size}")
		pd.logMessage("Pages Redacted: #{total_pages_redacted}")
		pd.logMessage("Errors: #{errors.size}")
		if errors.size > 0
			errors.each do |error|
				pd.logMessage(error)
			end
		end

		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end
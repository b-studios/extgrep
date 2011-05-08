#!/usr/bin/ruby1.9
class CommandLine

  @@_description = {}

  Description = Struct.new :name, :args, :desc

  def self.describe(method, args, description = "")
    desc = Description.new(method.to_s, args, description)
    @@_description[method.to_sym] = desc
  end

  def self.application(name, title, desc)
    @@_app = name.to_s
    self.describe(:app, title, desc)
  end


  def help(method = nil)
    puts "\n" * 40
    if not method.nil?      
      print_description method
    else      
     print_description(:app)
     puts "\n\n"
     @@_description.each do |method, desc| 
        puts "  #{desc.name} #{desc.args}\n\n" unless method == :app
      end
    end
    puts "\nType '#{@@_app} help $action_name' for further details\n\n"
  end

  protected

  def print_description(method)
    
    method = method.to_sym

    raise Exception.new("No description found for #{method}") unless @@_description.include?(method)

    desc = @@_description[method]
  
    puts "#{desc.name unless desc.name == "app"} #{desc.args}"
    puts "------------------------------------------\n"
    puts desc.desc
  end

end


class Grep < CommandLine
  
  BLOCKSIZE = 4096
  NEARBY = 100

  application :rbgrep, "Help for rbgrep (Ruby Grep)", "rbgrep is a quick and dirty solution for search and extraction of plain hard-disk data in ext3.
The default action is grep. type 'rbgrep help grep' for more details."



  describe :grep, "$path_to_file $searchstring $offset?", "Searches 'searchstring' in each block of 'file' starting at the optional block-'offset'. 

    Example usage: rbgrep grep file.img require_relative 433202

--> 433204 433210 433450 540392 603367"
  def grep(file_path, search_string, offset = 0)
     
    puts "searching for #{search_string}" 
  
    @blocks = []

    while buffer = IO.binread(file_path, BLOCKSIZE, offset*BLOCKSIZE) do
      if buffer.match(search_string)
        @blocks << offset
        puts "Block #{offset}: matched"
      end
      offset += 1
    end
    
    print_found(@blocks)
  end


  describe :nearby, "$path_to_file $searchstring $block1 $block2 ... $block_n", "Searches 'searchstring' in each block +-#{NEARBY} of the given 'blocks'. This is much faster
then searching through the whole file.

    Example usage: rbgrep nearby file.img my_search_string 433202 433405 500682
    --> 433204 433210 433450 500489 500767"
  def nearby(file, search_string, *blocks)
    puts "searching for #{search_string} around #{blocks.size} blocks +-#{NEARBY}" 
    raise Exception, "No blocks given to search nearby" if blocks.nil? or blocks.empty?

    blocks.map! { |block| block.to_i }.sort!

    @blocks = []

    # find ranges of sorted blocks
    ranges = find_ranges(blocks)
    
    ranges.each do |range|
      range.each do |block|
        block_data = read_block(file, block)
        @blocks << block if not block_data.nil? and block_data.match(search_string)
      end
    end

    @blocks.uniq!

    print_found(@blocks)
  end



  describe :print, "$path_to_file $offset $length", "Prints a single block (and the following, if 'length' > 1) to console

    Example usage: rbgrep print file.img 433202 2"
  def print(file_path, offset, length = 1)
    puts read_block(file_path, offset, length)
  end

  def inspect(file, block)
    
    block = block.to_i if block.is_a? String
    
    puts "\n--------------------------------------------------------------------------------------------------"
    puts print(file, block)
    puts "--------------------------------------------------------------------------------------------------\n"
    puts "(##{block}) Next Block (+) | Prev Block (-) | Jump to (Number)"
    
    case input = STDIN.gets.strip
    when '+', ''
      inspect(file, block+1)
    when '-'
      inspect(file, block-1) unless block == 1
    else
      inspect(file, input)
    end
  end


  describe :filter, "$path_to_file $block1 $block2 ... $blockn", "Can be used to filter the output of 'grep' or 'nearby'. Each block is printed to console to simplify the decision, if the block shall be filtered or not.

    Example usage: rbgrep filter my.file 455642 449852 456885 556452 345568
    --> 449852 345568
"
  def filter(file_path, *blocks)
    @filtered ||= []
    puts "Filtering #{blocks.length} block(s)"
    blocks.each do |block|       
      @filtered << block if analyse_block(file_path, block)
    end
    puts "----------------------------- FILTERED ----------------------------------"
    puts @filtered.join ' '
    @filtered
  end
 
  describe :restore, "$path_to_file $block1 $block2 ... $blockn", "Works similair as 'filter'. Each block will be printed. After that you can decide if the block (and following blocks) shall be written to file or not.

    Example usage: rbgrep restore my.file 455642 449852 456885 556452 345568"  
  def restore(file_path, *blocks)
    blocks.each do |block|       
      restore_block(file_path, block)
    end
  end

  protected

  def find_ranges(blocks, ranges = [])    

    return ranges if blocks.nil? or blocks.empty?
   
    block = blocks.shift

    # it's our first block
    if ranges.empty?
      if (block - NEARBY) <= 0
        ranges << Range.new(0, block + NEARBY)
      else
        ranges << Range.new(block - NEARBY, block + NEARBY)
      end

    # block is in last range, we have to extend our range
    elsif ranges.last.include?(block - NEARBY)
      range = ranges.last
      ranges[-1] = Range.new(range.first, block + NEARBY)
    
    # insert range
    else
      ranges << Range.new(block - NEARBY, block + NEARBY)
    end

    find_ranges(blocks, ranges)
  end

  def read_block(file, offset)
    IO.binread(file, BLOCKSIZE, offset*BLOCKSIZE)
  end

  def analyse_block(file, block, length = 1)
    puts "\n--------------------------------------------------------------------------------------------------"
    puts print(file, block, length)
    puts "--------------------------------------------------------------------------------------------------\n"
    puts "(##{block}:#{length}) More Blocks (+) | Less Blocks (-) | Keep (y) | Skip (x)"
    
    case STDIN.gets.strip
    when '+'
      analyse_block(file, block, length+1)
    when '-'
      analyse_block(file, block, length-1) unless length == 1
    when 'y'
      true
    else
      false
    end
  end

  def restore_block(file, block, length = 1)
    puts "\n--------------------------------------------------------------------------------------------------"
    puts print(file, block, length)
    puts "--------------------------------------------------------------------------------------------------\n"
    puts "(##{block}:#{length}) More Blocks (+) | Less Blocks (-) | Save (Filename) | Skip (x)"
    
    case input = STDIN.gets.strip
    when '+'
      restore_block(file, block, length+1)
    when '-'
      restore_block(file, block, length-1) unless length == 1
    when 'x'
      return nil
    else
      save_block(file, block, length, input)
    end
  end


  def save_block(file, block, length, input = nil)
    
    if input.nil?
      puts "Please specify filename, or 'c' for cancel"
      input = STDIN.gets.strip
    end

    return if input == 'c'

    if File.exists?(input)
      puts "#{input} already exists in current directory. Overwrite? (y/n)"
      save_block(file, block, length) if STDIN.gets.strip == 'n'
    end
    File.open(input, "w") do |f|
      f.write "# #{file}##{block}:#{length}\n"
      f.write read_block(file, block, length)
    end
  end

  def read_block(file_path, block_number, length = 1)
    # process input
    block_number = block_number.to_i unless block_number.is_a? Numeric
    length = length.to_i unless length.is_a? Numeric

    # puts "Printing with offset: #{offset} and length:#{length}"
    IO.binread(file_path, BLOCKSIZE*length, block_number*BLOCKSIZE).gsub(/\0+$/, '') # i know this is not performant
  end

  def print_found(blocks)
    puts "----------------------------- FOUND -------------------------------------"
    puts blocks.join ' '
    return blocks
  end
end

g = Grep.new

if ARGV.empty?
  g.send(:help)
elsif(g.respond_to? ARGV.first)
  g.send(ARGV.shift, *ARGV)
else
  g.grep(*ARGV)
end

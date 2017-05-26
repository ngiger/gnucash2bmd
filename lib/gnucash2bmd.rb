#!/usr/bin/env ruby

require 'trollop'
require 'date'
require 'csv'
require 'ostruct'
require 'gnucash2bmd/version'
require 'pp'
begin
  require 'pry'
rescue LoadError
end

OLD_YEAR =  Date.today.year - 2
files_read = [
  "Aufwendungen#{OLD_YEAR}.csv",
]

opts = Trollop::options do
  banner <<-EOS
Erstellen einer CSV Datei für BMD-Import
  Gemäss http://www.bmd.at/Portaldata/1/Resources/help/17.26/OES/Documents/1109441501000002470.html
  Bedingung: Gnucash-Inhalt muss wie folgt exportiert worden sein
  Annahmen: Keine Fremdwährungen
  Folgende Dateien werden eingelesen
    Konten#{OLD_YEAR}.csv
    #{files_read.join("\n")}

Erzeugt eine Datei #{OLD_YEAR}_bmd.csv

Gebrauch:
       #{__FILE__} [options]
Wobei folgende Optionen vorhanden sind:
EOS
  opt :jahr, "Jahr des Gnucas-Exports", :type => :integer, :default=> OLD_YEAR
  opt :ausgabe, "Name der erstellten Datei", :type => :string, :default =>"bmd_#{OLD_YEAR}.csv"
end

files_read = [
  "Aufwendungen#{ opts[:jahr]}.csv",
]

AUSGABE = opts[:ausgabe]

KONTEN_GNUCASH_HEADERS = {
  'type' => nil,
  'Vollständige_Bezeichnung' => 'Mandats-IDs',
  'Name' => nil,
  'Kontonummer' => 'bank-kontonr',
  'Beschreibung' => '',
  'Farbe' => '',
  'Bemerkung' => '',
  'Devise/Wertpapier M' => '',
  'Devise/Wertpapier N' => '',
  'Versteckt' => '',
  'Steuerrelevant' => '',
  'Platzhalter' => '',
  }
KONTEN_JOURNAL_HEADERS = {
  'Datum' => 'buchdatum',
  'Kontobezeichnung' => 'konto',
  'Nummer' => 'belegnr',
  'Beschreibung' => '',
  'Bemerkung' => '',
  'Buchungstext' => 'text',
  'Kategorie' => '',
  'Kontoart' => '',
  'Aktion' => '',
  'Abgleichen' => '',
  'To With Sym' => '',
  'From With Sym' => '',
  'Bis Nr.' => '',
  'Von Nr.' => '',
  'Zu Kurs/Preis' => '',
  'Von Kurs/Preis' => '',
}
  Mandant_ID = 1

  BMD_LINE = OpenStruct.new
  BANK_GUIDS ||= {}
  IDS =  {
    :satzart  => 'satzart',
#    :mandant => 'Mandats-IDs',
    :account_nr => 'bank-kontonr',
    :bank_guid => 'bank-guid',
    :konto => 'konto',
    :gkonto => 'gkonto',
    :buchdatum => 'buchdatum',
    :buchungstext => 'buchungstext',
    :betrag => 'betrag',
    :belegnr => 'belegnr',
    :buchcode => 'buchcode',
    }
  class Helpers
    IDS.each do |id, name|
      eval("attr_accessor :#{id}")
    end
    def id_to_name(id)
      return @@ids[ide]
    end
    def self.new_account
      info = OpenStruct.new(:satzart =>0)
      return info
    end
    def self.search_bank_guid(konto_bezeichung)
      if value = BANK_GUIDS.key(konto_bezeichung)
        return value
      end
      new_id = BANK_GUIDS.size + 1
      BANK_GUIDS[new_id] = konto_bezeichung
      new_id
    end
    def Helpers.get_ids_sorted_by_value
      IDS.sort_by.reverse_each{ |k, v| v }.to_h
    end

  end
@contents = []

def read_accounts(filename)
  line_nr = 0
  CSV.foreach(filename) do |row|
    line_nr += 1
    if line_nr == 1
      # TODO: Check headers
    else
      name_voll = row[1]
      bezeichung = row[2]
      next unless bezeichung && bezeichung.size > 0
      bmd = Helpers.new_account
      bmd.bank_guid = Helpers.search_bank_guid(bezeichung)
      bmd.account_nr = bezeichung
      @contents << bmd
    end
  end
end


# Journal file start a new Journal entry only when the accout date is given
def getBuchcode(betrag)
  betrag.to_f > 0.0 ? 1 : 2
end

def read_journal(filename)
  line_nr = 0
  @bmd = nil
  @mehrteilig
  @buchungs_nr = 0 # Will be added by column Aktion
  puts "reading journal from #{filename}"
  CSV.foreach(filename) do |row|
    line_nr += 1
    if line_nr == 1
      # TODO: Check headers
    else
      row.each_with_index{|val, idx| puts "#{sprintf('%-3d', idx)} #{val}" } if $VERBOSE
      if $VERBOSE && (/100000769/.match( row[3]) || (@bmd && /100000769/.match(@bmd.buchungstext)))
        puts "100000769 in #{filename}:#{line_nr} is #{row}"
        pp @bmd
      end
      if ( buchdatum = row[0]) && buchdatum.size > 0
        @contents << @bmd if @bmd # save terminated
        @buchungs_nr += 1
        @mehrteilig = row[6] && /mehrteilig/i.match(row[6])
        @bmd = Helpers.new_account
        @bmd.buchdatum = row[0]
        @bmd.konto = Helpers.search_bank_guid(row[1])
        @bmd.buchungstext = row[3]
        @bmd.belegnr = "#{@buchungs_nr} aktion #{row[2]}"
      elsif (betrag = row[12]) && betrag.size > 0
        @bmd.betrag = betrag
        @bmd.buchcode =getBuchcode(betrag)
        @bmd.konto = Helpers.search_bank_guid(row[6])
        @contents << @bmd
        @bmd = @bmd.clone
        @bmd.konto = nil
      elsif (betrag = row[13]) && betrag.size > 0
        @bmd.betrag = betrag
        @bmd.buchcode =getBuchcode(betrag)
        @bmd.gkonto = Helpers.search_bank_guid(row[6])
        @contents << @bmd
        @bmd = @bmd.clone
        @bmd.gkonto = nil
      else
        # probably the last line
        @contents << @bmd if @bmd
        @bmd = nil
      end
    end
  end
  @contents << @bmd if @bmd # save terminated
end

def check_cmd(filename)
  nr_rows = nil
  idx = 0
  CSV.foreach(filename,  :col_sep => ';') do |row|
    idx += 1
    nr_rows ||= row.size
    unless nr_rows == row.size
      puts "Expected #{nr_rows} not #{row.size} in line #{idx}"
      puts "   #{row}"
      exit 2
    end
  end
  puts "All #{idx} lines of #{filename} have #{nr_rows} elements"
rescue => error
  puts "got #{error} at line #{idx}"
end

def emit_bmd(filename)
  CSV.open(filename, "wb", :encoding => 'UTF-8', :force_quotes  => true, :col_sep => ';') do |csv|
    csv << IDS.values
    @contents.each do |content|
      value_array = []
      IDS.keys.each do |key|
        begin
          value_array << eval("content.#{key} || nil")
        rescue => error
          binding.pry
        end
      end
      csv << value_array
    end
  end
end

read_accounts("Konten#{OLD_YEAR}.csv")
BANK_GUIDS.freeze
files_read.each do |filename|
  read_journal(filename)
end
emit_bmd(AUSGABE)
check_cmd(AUSGABE)

puts "Created #{AUSGABE} with #{@contents.size} lines"

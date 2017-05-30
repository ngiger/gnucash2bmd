#!/usr/bin/env ruby

require 'trollop'
require 'date'
require 'csv'
require 'ostruct'
require 'gnucash2bmd/version'
require 'pp'
require "gnucash"
require 'zlib'

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
  opt :gnucash, "Name der zu lesenden Gnucash-Datei", :type => :string, :default => nil
end

files_read = [
  "Aufwendungen#{ opts[:jahr]}.csv",
]

AUSGABE = opts[:ausgabe]
GNUCASH = opts[:gnucash]
DATE_FORMAT= '%d.%m.%Y'

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

  BANK_GUIDS ||= {}
  NOTWNDIG = %(
  Notwendige Felder für den BuErf Import:
Grundsätzlich alle Felder, die Sie auch beim "manuellen" Buchen in der Buchungsmaske eingeben:
  Konto Führendes Buchungskonto
  Gkonto Gegenkonto
  Belegnr Belegnummer, Rechnungsnummer
  Buchdatum Buchungsdatum
  Belegdatum Belegdatum, Rechnungsdatum
  Buchcode Code, ob Soll oder Haben
  Betrag Buchungsbetrag für führendes Konto
  Text Buchungstext

Buchsymbol Buchungssymbol AR
Steuercode Code, ob Vorsteuer oder Umsatzsteuer usw.
Prozent Steuerprozentsatz
Steuer Steuerbetrag
ZZiel Nettozahlungsziel in Tagen
Skontopz Skontoprozentsatz
Skontotage Skontozahlungsziel in Tagen
)
  IDS =  {
    :satzart  => 'satzart',
#    :mandant => 'Mandats-IDs',
    :account_nr => 'bank-kontonr',
    :bank_guid => 'bank-guid',
    :konto => 'konto',
    :gkonto => 'gkonto',
    :buchdatum => 'buchdatum',
    :belegdatum => 'belegdatum',
    :buchungstext => 'text',
    :betrag => 'betrag',
    :belegnr => 'belegnr',
    :buchcode => 'buchcode',

    :buchsymbol => 'buchsymbol',
    :steuercode => 'steuercode',
    :prozent => 'prozent',
    :steuer => 'steuer',
    :zziel => 'zziel',
    :skontopz => 'skontopz',
    :skontotage => 'skontotage',
    }
  DEFAULTS = {
    :buchsymbol => 'AR',
    :steuercode => '0,0',
    :prozent => '0,0',
    :steuer => '0,0',
    :zziel => '30',
    :skontopz => '0,0',
    :skontotage => '10',
    }
  BMD_LINE = eval("Struct.new( :#{IDS.keys.join(', :')})")
  class BMD_LINE
    attr_accessor :name, :name_voll
    def satzart
      0
    end
  end
  class Helpers
    IDS.each do |id, name|
      eval("attr_accessor :#{id}")
    end
    def id_to_name(id)
      return @@ids[ide]
    end
    def self.search_bank_guid(konto_bezeichung)
      if value = BANK_GUIDS.key(konto_bezeichung)
        return value
      end
      new_id = BANK_GUIDS.size + 1
      BANK_GUIDS[new_id] = konto_bezeichung
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
      bmd = BMD_LINE.new
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
  @mehrteilig = nil
  @buchungs_nr = 0 # Will be added by column Aktion
  puts "reading journal from #{filename}"
  konto = KONTEN_JOURNAL_HEADERS.values.index('konto')
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
        @bmd = BMD_LINE.new
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
  konto_row = IDS.keys.index(:konto)
  gkonto_row = IDS.keys.index(:gkonto)
  guid_row = IDS.keys.index(:bank_guid)
  belegnr_row = IDS.keys.index(:belegnr)
  CSV.foreach(filename,  :col_sep => ';') do |row|
    idx += 1
    nr_rows ||= row.size
    unless nr_rows == row.size
      puts "Expected #{nr_rows} not #{row.size} in line #{idx}"
      puts "   #{row}"
      exit 2
    end
    next if idx == 1
    if row[belegnr_row]
      value = row[belegnr_row]
      raise "Zeile #{idx} für Beleg-Nr '#{value}' darf maximal 20 Zeichen lang sein (ist #{value.length})." if value.length > 20
      raise "Zeile #{idx} für Beleg-Nr  '#{value}' muss alphanumerisch sein." unless  /^[a-z0-9]+$/i.match(value)
    end
    if row[guid_row]
      value = row[guid_row]
      raise "Zeile #{idx} für GUID '#{value}' darf maximal 36 Zeichen lang sein (ist #{value.length})." if value.length > 36
      raise "Zeile #{idx} für GUID '#{value}' muss alphanumerisch sein." unless  /^[a-z0-9]+$/i.match(value)
    end
    if row[gkonto_row]
      value = row[gkonto_row]
      raise "Zeile #{idx} für Gkonto '#{value}' muss eine Zeile angegeben werden" unless value.to_i > 0 && value.size < 10
    end
    if row[konto_row]
      value = row[konto_row]
      raise "Zeile #{idx} für Konto '#{value}' muss eine Zeile angegeben werden" unless value.to_i > 0 && value.size < 10
    end
  end
  puts "Alle #{idx} Zeilen von #{filename} haben #{nr_rows} Elemente"
rescue => error
  puts "got #{error} at line #{idx}"
end

def emit_bmd(filename)
  CSV.open(filename, "wb", :encoding => 'UTF-8', :col_sep => ';') do |csv|
    csv << IDS.values
    @contents.uniq.each do |content|
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

def read_gnucash(filename)
  puts "Lese GnuCash Datei #{filename}"
  book = Gnucash.open(filename)
  book.accounts.each do |account|
    bmd = BMD_LINE.new
    bmd.bank_guid = Helpers.search_bank_guid(account.id)
    # bmd.bank_guid = account.id
    bmd.name = account.name
    bmd.name_voll = account.full_name
    bmd.account_nr = account.description
    $stdout.puts "bmd; #{bmd}" if $VERBOSE
    @contents << bmd
  end
  @first_transaction_date = nil
  @last_transaction_date = nil
  @buchungs_nr = 0
  book.accounts.each do |account|
    balance = Gnucash::Value.zero
    account.transactions.each do |txn|
      balance += txn.value
      @buchungs_nr += 1
      # $VERBOSE = true if /-408.00/.match(txn.value.to_s)
      $stdout.puts(sprintf("%s  %8s  %8s  %s",
                          txn.date,
                          txn.value,
                          balance,
                          txn.description))  if $VERBOSE
      @buchung              = BMD_LINE.new
      @buchung.buchdatum    = txn.date.strftime(DATE_FORMAT)
      @last_transaction_date  = @buchung.buchdatum if !@last_transaction_date  || @last_transaction_date  < @buchung.buchdatum
      @first_transaction_date = @buchung.buchdatum if !@first_transaction_date || @first_transaction_date > @buchung.buchdatum
      @buchung.buchungstext = txn.description
      @buchung.belegnr      = @buchungs_nr # txn.id ist 32 Zeichen lang. Ungültig!!
      @buchung.belegdatum   = @buchung.buchdatum
      DEFAULTS.each do |key, value|
        cmd = "@buchung.#{key} = '#{value}'"
        eval cmd
      end


      if txn.splits.size == 2
        @buchung.konto    = Helpers.search_bank_guid(txn.splits.first[:account].id)
        @buchung.gkonto   = Helpers.search_bank_guid(txn.splits.last[:account].id)
        @buchung.betrag   = txn.splits.first[:value]
        @buchung.buchcode = getBuchcode(txn.splits.first[:value])
        @contents << @buchung
      else
        # Splittbuchungen werden vom Programm automatisch erkannt, wenn in mehreren aufeinanderfolgenden Buchungszeilen folgende Felder identisch sind:
        # Konto
        # Belegnr
        # Belegdatum
        gegenbuchungen = []
        txn.splits.each_with_index do |split, idx|
          $stdout.puts(sprintf("idx %d: %s  %8s   %8s",
                               idx,
                              split[:quantity],
                              split[:value],
                              split[:account].id,
                              ))
        end if $VERBOSE
        txn.splits.each_with_index do |split, idx|
          if txn.value.to_s.eql?(split[:value].to_s)
            @buchung.konto    = Helpers.search_bank_guid(split[:account].id)
            @buchung.betrag   = split[:value]
            @buchung.buchcode = getBuchcode(split[:value])
          else
            gegenbuchung = @buchung.clone
            gegenbuchung.gkonto = Helpers.search_bank_guid(split[:account].id)
            gegenbuchung.betrag = split[:value]
            gegenbuchung.buchcode = getBuchcode(split[:value])
            gegenbuchungen << gegenbuchung
          end
        end
        gegenbuchungen.each do |info| info.konto = @buchung.konto;  @contents << info; end
      end
    end
  end
  puts "Las #{@buchungs_nr} Buchungen von #{filename} vom #{@first_transaction_date} bis zum #{@last_transaction_date}"
end
if GNUCASH
  read_gnucash(GNUCASH)
else
  read_accounts("Konten#{OLD_YEAR}.csv")
  BANK_GUIDS.freeze
  files_read.each do |filename|
    read_journal(filename)
  end
end
emit_bmd(AUSGABE)
check_cmd(AUSGABE)

puts "Erstellte #{AUSGABE} mit #{@contents.size} Zeilen"

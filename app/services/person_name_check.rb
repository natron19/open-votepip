# Code-side guard on AI output (not trusted to the model): the clarity check must never name a person.
#
# Adapted from production VotePIP's PersonNameCheck, which compares the output with the organization's member
# roster. This demo has no roster, so it pulls likely person names out of the member's own draft and fails the
# output when it repeats one:
#
#   - a title followed by a capitalized word ("Pastor Abernathy", "Treasurer Whitlock", "Ms. Okafor");
#   - two or three capitalized words in a row ("Dana Whitlock") with no place or organization word
#     ("Elm Street", "Tool Library") and no common capitalized word (days, months, "The", ...).
#
# A full name matches case-insensitively on word boundaries. A surname alone matches only when capitalized and
# when the input and output never use it as an ordinary lowercase word, so "green space" does not trip on
# "Dana Green". First names alone are never flagged, as in production. It is a heuristic that errs toward
# blocking; a blocked check shows the member a plain reason and a Retry button.
class PersonNameCheck
  Name = Struct.new(:full, :surname, keyword_init: true)

  TITLES = %w[
    Mr Mrs Ms Mx Miss Dr Rev Reverend Pastor Father Sister Brother Elder Deacon Rabbi Imam Bishop Cantor
    Councillor Councilor Alderman Alderwoman Mayor Coach Professor Prof Treasurer Chair Chairperson Secretary
    President Director Captain Officer Judge Senator Auntie Uncle
  ].freeze

  STOPWORDS = %w[
    The A An And Or But Nor Of In On At For To By From With Without Into Onto Over Under After Before During
    Until Since As If When While Where Why How What Which Who Whom Whose That This These Those There Here
    Our Your Their My His Her Its We You They I He She It Us Them Every Each All Any Some No Not Yes Please
    Thank Thanks Also Then So Let Lets Starting Beginning Members Member Everyone Everybody Nobody Anyone None
    Monday Tuesday Wednesday Thursday Friday Saturday Sunday
    January February March April May June July August September October November December
    Christmas Easter Thanksgiving Ramadan Passover Diwali Hanukkah
  ].freeze

  ORG_WORDS = %w[
    Street St Road Rd Avenue Ave Lane Drive Way Boulevard Blvd Place Square Park Garden Gardens Hall Room Rooms
    Center Centre Library School Church Chapel Temple Mosque Synagogue Meeting House Housing Co-op Coop
    Cooperative Association Society Club Committee Council Board Fund Trust Foundation Union League Network
    Group Team Commons Community Neighborhood Neighbourhood Village Town City County State Market Fair Festival
    Day Night Week Month Year Annual Kitchen Pantry Bank Shop Store Cafe Building Tower Court Commission Assembly
    Circle Collective Project Program Programme Plan Policy Rule Rules Bylaws Bylaw Section Article Act Agreement
    Lake River Creek Hill Hills Valley Woods Forest Bridge Station North South East West Upper Lower New Old
    Saint Mount Tool Tools Lobby Office Department Ministry Mission Shelter Clinic Hospital Farm Orchard Field
    Fields Playground Pool Gym Studio Theater Theatre Museum Gallery Reserve Budget Account Hub Lab Works
  ].freeze

  WORD = /[A-Z][a-zA-Z]*[a-z](?:['’-][A-Za-z]+)*/
  RUN  = /(?<![[:alnum:]])#{WORD}(?:[ \t]+#{WORD})*(?![[:alnum:]])/
  ABBREVIATED_TITLE = /\b(Mr|Mrs|Ms|Mx|Dr|Rev|Prof|St)\./

  # Names from `input` that appear in `output`, as strings (empty when the output is clean).
  def self.found_in(output, input)
    text   = output.to_s
    plain  = ordinary_words(input.to_s + "\n" + text)
    names_in(input).filter_map do |name|
      if name.full && text.match?(bounded(name.full, ignore_case: true))
        name.full
      elsif name.surname && !plain.include?(name.surname.downcase) && text.match?(bounded(name.surname, ignore_case: false))
        name.surname
      end
    end.uniq
  end

  def self.clean?(output, input)
    found_in(output, input).empty?
  end

  # Likely person names in a block of text.
  def self.names_in(text)
    text  = text.to_s.gsub(ABBREVIATED_TITLE, '\1')
    plain = ordinary_words(text)
    names = []

    text.each_line do |line|
      next if headline?(line)

      line.scan(RUN).each do |run|
        words = run.split(/[ \t]+/)
        names.concat(names_from_titles(words))
        names.concat(names_from_run(words.reject { |w| TITLES.include?(w) }, plain))
      end
    end
    names.uniq
  end

  # A title-cased heading ("Extend Tool Library Hours") reads as a run of capitals but is not a name.
  def self.headline?(line)
    words = line.scan(/[A-Za-z][\w'’-]*/)
    return false if words.size < 4
    capitalized = words.count { |w| w.match?(/\A[A-Z]/) }
    capitalized.to_f / words.size >= 0.75
  end

  # "Treasurer Whitlock", "Pastor Ruth Abernathy": the words after a title, up to a stopword.
  def self.names_from_titles(words)
    words.each_index.filter_map do |i|
      next unless TITLES.include?(words[i])
      following = words[(i + 1)..].take_while { |w| name_word?(w) }.first(3)
      next if following.empty?
      Name.new(full: following.size >= 2 ? following.join(" ") : nil, surname: following.last)
    end
  end

  # "Dana Whitlock": 2-3 name-like words in a row. A leading word the text also uses in lowercase
  # ("Thank", "Extend") is an ordinary word at the start of a sentence, not part of a name.
  def self.names_from_run(words, plain)
    return [] if words.any? { |w| ORG_WORDS.include?(w) }

    words.slice_when { |a, b| !name_word?(a) || !name_word?(b) }
         .map { |seg| seg.select { |w| name_word?(w) } }
         .map { |seg| seg.drop_while { |w| plain.include?(w.downcase) } }
         .select { |seg| seg.size.between?(2, 3) }
         .map { |seg| Name.new(full: seg.join(" "), surname: seg.last) }
  end

  def self.name_word?(word)
    !STOPWORDS.include?(word) && !ORG_WORDS.include?(word) && !TITLES.include?(word)
  end

  def self.ordinary_words(text)
    text.scan(/(?<![[:alnum:]])[a-z][a-z'’-]+/).to_set
  end

  def self.bounded(phrase, ignore_case:)
    Regexp.new("(?<![[:alnum:]])#{Regexp.escape(phrase)}(?![[:alnum:]])", ignore_case ? Regexp::IGNORECASE : nil)
  end

  private_class_method :headline?, :names_from_titles, :names_from_run, :name_word?, :ordinary_words, :bounded
end

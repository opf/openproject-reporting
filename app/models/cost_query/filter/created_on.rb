class CostQuery::Filter::CreatedOn < Report::Filter::Base
  db_field "entries.created_on"
  use :time_operators

  def self.label
    Issue.human_attribute_name(:created_on)
  end
end

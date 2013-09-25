class CostQuery::Filter::UserId < Report::Filter::Base
  def self.label
    WorkPackage.human_attribute_name(:user)
  end

  def self.available_values(*)
    users = Project.visible.collect {|p| p.users}.flatten.uniq.sort
    values = users.map { |u| [u.name, u.id] }
    values.delete_if { |u| (u.first.include? "OpenProject Admin") || (u.first.include? "Anonymous")}
    values.sort!
    values.unshift ["<< #{::I18n.t(:label_me)} >>", User.current.id.to_s] if User.current.logged?
    values
  end
end

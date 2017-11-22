#-- copyright
# OpenProject Costs Plugin
#
# Copyright (C) 2009 - 2014 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#++

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe "updating a cost report's cost type", type: :feature, js: true do
  let(:project) { FactoryGirl.create :project_with_types }
  let(:user) do
    FactoryGirl.create(:admin).tap do |user|
      project.add_member! user, FactoryGirl.create(:role)
    end
  end

  let(:cost_type) do
    FactoryGirl.create :cost_type, name: 'Post-war', unit: 'cap', unit_plural: 'caps'
  end

  let!(:cost_entry) do
    FactoryGirl.create :cost_entry, user: user, project: project, cost_type: cost_type
  end

  before do
    login_as(user)
  end

  it 'works' do
    visit "/projects/#{project.identifier}/cost_reports"

    click_on "Save"
    fill_in "query_name", with: "My Query"
    check "query_is_public"

    within "#save_as_form" do
      click_on "Save"
    end

    choose cost_type.name

    click_on "Apply"
    click_on "Save"

    click_on "My Query"

    option = all("[name=unit]").last

    expect(option).to be_checked
    expect(option.value).to eq cost_type.id.to_s
  end
end

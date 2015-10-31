#-- copyright
# OpenProject Reporting Plugin
#
# Copyright (C) 2010 - 2014 the OpenProject Foundation (OPF)
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

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe CostQuery, type: :model, reporting_query_helper: true do
  before do
    FactoryGirl.create(:admin)
    project = FactoryGirl.create(:project_with_types)
    work_package = FactoryGirl.create(:work_package, project: project)
    FactoryGirl.create(:time_entry, work_package: work_package, project: project)
    FactoryGirl.create(:cost_entry, work_package: work_package, project: project)
  end

  minimal_query

  describe CostQuery::Result do
    def direct_results(quantity = 0)
      (1..quantity).map {|i| CostQuery::Result.new real_costs:i.to_f, count:1 ,units:i.to_f}
    end

    def wrapped_result(source, quantity=1)
      CostQuery::Result.new((1..quantity).map { |_i| source})
    end

    it "should travel recursively depth-first" do
      #build a tree of wrapped and direct results
      w1 = wrapped_result((direct_results 5), 3)
      w2 = wrapped_result wrapped_result((direct_results 3), 2)
      w = wrapped_result [w1, w2]
      previous_depth = -1
      w.recursive_each_with_level do |level, result|
        #depth first, so we should get deeper into the hole, until we find a direct_result
        expect(previous_depth).to eq(level - 1)
        previous_depth=level
        break if result.is_a? CostQuery::Result::DirectResult
      end
    end

    it "should travel recursively width-first" do
      #build a tree of wrapped and direct results
      w1 = wrapped_result((direct_results 5), 3)
      w2 = wrapped_result wrapped_result((direct_results 3), 2)
      w = wrapped_result [w1, w2]

      previous_depth = -1
      w.recursive_each_with_level 0, false do |level, _result|
        #width first, so we should get only deeper into the hole without ever coming up again
        expect(previous_depth).to be <= level
        previous_depth=level
      end
    end

    it "should travel to all results width-first" do
      #build a tree of wrapped and direct results
      w1 = wrapped_result((direct_results 5), 3)
      w2 = wrapped_result wrapped_result((direct_results 3), 2)
      w = wrapped_result [w1, w2]

      count = 0
      w.recursive_each_with_level 0, false do |_level, result|
        #width first
        count = count + 1 if result.is_a? CostQuery::Result::DirectResult
      end
      expect(w.count).to eq(count)
    end

    it "should travel to all results width-first" do
      #build a tree of wrapped and direct results
      w1 = wrapped_result((direct_results 5), 3)
      w2 = wrapped_result wrapped_result((direct_results 3), 2)
      w = wrapped_result [w1, w2]

      count = 0
      w.recursive_each_with_level do |_level, result|
          #depth first
          count = count + 1 if result.is_a? CostQuery::Result::DirectResult
        end
      expect(w.count).to eq(count)
    end

    it "should compute count correctly" do
      expect(@query.result.count).to eq(Entry.count)
    end

    it "should compute units correctly" do
      expect(@query.result.units).to eq(Entry.all.map { |e| e.units}.sum)
    end

    it "should compute real_costs correctly" do
      expect(@query.result.real_costs).to eq(Entry.all.map { |e| e.overridden_costs || e.costs}.sum)
    end

    it "should compute count for DirectResults" do
      expect(@query.result.values[0].count).to eq(1)
    end

    it "should compute units for DirectResults" do
      id_sorted = @query.result.values.sort_by { |r| r[:id] }
      te_result = id_sorted.find { |r| r[:type]==TimeEntry.to_s }
      ce_result = id_sorted.find { |r| r[:type]==CostEntry.to_s }
      expect(te_result.units.to_s).to eq("1.0")
      expect(ce_result.units.to_s).to eq("1.0")
    end

    it "should compute real_costs for DirectResults" do
      id_sorted = @query.result.values.sort_by { |r| r[:id] }
      [CostEntry].each do |type|
        result = id_sorted.find { |r| r[:type]==type.to_s }
        first = type.all.first
        expect(result.real_costs).to eq(first.overridden_costs || first.costs)
      end
    end

    it "should be a column if created with CostQuery.column" do
      @query.column :project_id
      expect(@query.result.type).to eq(:column)
    end

    it "should be a row if created with CostQuery.row" do
      @query.row :project_id
      expect(@query.result.type).to eq(:row)
    end

    it "should show the type :direct for its direct results" do
      @query.column :project_id
      expect(@query.result.first.first.type).to eq(:direct)
    end

  end
end

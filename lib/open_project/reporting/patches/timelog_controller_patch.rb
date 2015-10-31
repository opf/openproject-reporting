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

require_dependency 'timelog_controller'

module OpenProject::Reporting::Patches
  module TimelogControllerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do

        alias_method_chain :index, :reports_view
        alias_method_chain :find_optional_project, :own
      end
    end

    module InstanceMethods

      ##
      # @Override
      # This is for cost reporting
      def redirect_to(*args, &block)
        if args.first == :back and args.size == 1 and request.referer =~ /cost_reports/
          super(controller: '/cost_reports', action: :index)
        else
          super(*args, &block)
        end
      end

      def index_with_reports_view
        # we handle single project reporting currently
        if @project.nil? || !@project.module_enabled?(:reporting_module)
          return index_without_reports_view
        end
        filters = { operators: {}, values: {} }

        if @issue
          if @issue.respond_to?("lft")
            work_package_ids = @issue.self_and_descendants.pluck(:id)
          else
            work_package_ids = [@issue.id.to_s]
          end

          filters[:operators][:work_package_id] = "="
          filters[:values][:work_package_id] = [work_package_ids]
        end

        filters[:operators][:project_id] = "="
        filters[:values][:project_id] = [@project.id.to_s]

        respond_to do |format|
          format.html {
            session[::CostQuery.name.underscore.to_sym] = { filters: filters, groups: { rows: [], columns: [] } }

            redirect_to controller: "/cost_reports", action: "index", project_id: @project, unit: -1
          }
          format.all {
            index_without_report_view
          }
        end
      end

      def find_optional_project_with_own
        if !params[:work_package_id].blank?
          @issue = WorkPackage.find(params[:work_package_id])
          @project = @issue.project
        elsif !params[:project_id].blank?
          @project = Project.find(params[:project_id])
        end
        deny_access unless User.current.allowed_to?(:view_time_entries, @project, global: true) ||
                           User.current.allowed_to?(:view_own_time_entries, @project, global: true)
      end
    end
  end
end

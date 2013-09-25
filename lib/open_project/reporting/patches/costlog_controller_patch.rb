require_dependency 'costlog_controller'

module OpenProject::Reporting::Patches::CostlogControllerPatch
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable

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
        super(:controller => '/cost_reports', :action => :index)
      else
        super(*args, &block)
      end
    end

    def index_with_reports_view
      # we handle single project reporting currently
      if @project.nil? || !@project.module_enabled?(:reporting_module)
        return index_without_reports_view
      end
      filters = {:operators => {}, :values => {}}

      if @work_package
        if @work_package.respond_to?("lft")
          work_package_ids = WorkPackage.all(:select => :id, :conditions => ["root_id = ? AND lft >= ? AND rgt <= ?", @work_package.root_id, @work_package.lft, @work_package.rgt]).collect{|i| i.id}
        else
          work_package_ids = [@work_package.id]
        end

        filters[:operators][:work_package_id] = "="
        filters[:values][:work_package_id] = work_package_ids
      end

      filters[:operators][:project_id] = "="
      filters[:values][:project_id] = [@project.id.to_s]

      respond_to do |format|
        format.html {
          session[CostQuery.name.underscore.to_sym] = { :filters => filters, :groups => {:rows => [], :columns => []} }

          if @cost_type
            redirect_to :controller => "/cost_reports", :action => "index", :project_id => @project, :unit => @cost_type.id
          else
            redirect_to :controller => "/cost_reports", :action => "index", :project_id => @project
          end
          return
        }
        format.all {
          index_without_report_view
        }
      end
    end

    def find_optional_project_with_own
      find_optional_project_without_own
      deny_access unless User.current.allowed_to?(:view_cost_entries, @project, :global => true) ||
                         User.current.allowed_to?(:view_own_cost_entries, @project, :global => true)
    end
  end
end

CostlogController.send(:include, OpenProject::Reporting::Patches::CostlogControllerPatch)

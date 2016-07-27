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

class CostReportsController < ApplicationController
  rescue_from Exception do |exception|
    session.delete(CostQuery.name.underscore.to_sym)
    raise exception
  end

  rescue_from ActiveRecord::RecordNotFound do |_exception|
    render_404
  end

  Widget::Base.dont_cache!

  before_filter :check_cache
  before_filter :load_all
  before_filter :find_optional_project
  before_filter :find_optional_user
  include Report::Controller
  before_filter :set_cost_types # has to be set AFTER the Report::Controller filters run

  verify method: :delete, only: %w[destroy]
  verify method: :post, only: %w[create, update, rename]

  helper_method :cost_types
  helper_method :cost_type
  helper_method :unit_id
  helper_method :public_queries
  helper_method :private_queries

  attr_accessor :cost_types, :unit_id, :cost_type

  # Checks if custom fields have been updated, added or removed since we
  # last saw them, to rebuild the filters and group bys.
  # Called once per request.
  def check_cache
    CostQuery::Cache.check
  end

  ##
  # @Override
  # Use respond_to hook, so redmine_export can hook up the excel exporting
  def index
    super
    respond_to do |format|
      format.html {
        session[report_engine.name.underscore.to_sym].try(:delete, :name)
        render action: 'index'
      }
    end unless performed?
  end

  current_menu_item :index do
    :cost_reports_global
  end

  def drill_down
    redirect_to action: :index
  end

  ##
  # Determines if the request sets a unit type
  def set_unit?
    params[:unit]
  end

  ##
  # @Override
  # We cannot show a progressbar in Redmine, due to Prototype being less than 1.7
  def no_progress?
    true
  end

  ##
  # Set a default query to cut down initial load time
  def default_filter_parameters
    { operators: { user_id: '=', spent_on: '>d' },
      values: { user_id: [User.current.id], spent_on: [30.days.ago.strftime('%Y-%m-%d')] }
    }.tap do |hash|
      if @project
        hash[:operators].merge! project_id: '='
        hash[:values].merge! project_id: [@project.id]
      end
    end
  end

  ##
  # Set a default query to cut down initial load time
  def default_group_parameters
    { columns: [:week], rows: [] }.tap do |h|
      if @project
        h[:rows] << :work_package_id
      else
        h[:rows] << :project_id
      end
    end
  end

  ##
  # We apply a project filter, except when we are just applying a brand new query
  def ensure_project_scope!(filters)
    return unless ensure_project_scope?
    if @project
      filters[:operators].merge! project_id: '='
      filters[:values].merge! project_id: @project.id.to_s
    else
      filters[:operators].delete :project_id
      filters[:values].delete :project_id
    end
  end

  def ensure_project_scope?
    !(set_filter? or set_unit?)
  end

  ##
  # Determine active cost types, the currently selected unit and corresponding cost type
  def set_cost_types
    set_active_cost_types
    set_unit
    set_cost_type
  end

  # Determine the currently active unit from the parameters or session
  #   sets the @unit_id -> this is used in the index for determining the active unit tab
  def set_unit
    @unit_id = if set_unit?
                 params[:unit].to_i
               elsif @query.present?
                 cost_type_filter =  @query.filters.detect { |f| f.is_a?(CostQuery::Filter::CostTypeId) }

                 cost_type_filter.values.first.to_i if cost_type_filter
    end

    @unit_id = -1 unless @cost_types.include? @unit_id
  end

  # Determine the active cost type, if it is not labor or money, and add a hidden filter to the query
  #   sets the @cost_type -> this is used to select the proper units for display
  def set_cost_type
    if @unit_id != 0 && @query
      @query.filter :cost_type_id, operator: '=', value: @unit_id.to_s, display: false
      @cost_type = CostType.find(@unit_id) if @unit_id > 0
    end
  end

  #   set the @cost_types -> this is used to determine which tabs to display
  def set_active_cost_types
    unless session[:report] && (@cost_types = session[:report][:filters][:values][:cost_type_id].try(:collect, &:to_i))
      relevant_cost_types = CostType.select(:id).order('id ASC').select do |t|
        t.cost_entries.count > 0
      end.collect(&:id)
      @cost_types = [-1, 0, *relevant_cost_types]
    end
  end

  def load_all
    CostQuery::GroupBy.all
    CostQuery::Filter.all
  end

  # @Override
  def determine_engine
    @report_engine = CostQuery
    @title = "label_#{@report_engine.name.underscore}"
  end

  # N.B.: Users with save_cost_reports permission implicitly have
  # save_private_cost_reports permission as well
  #
  # @Override
  def allowed_to?(action, report, user = User.current)
    # admins may do everything
    return true if user.admin?

    # If this report does belong to a project but not to the current project, we
    # should not do anything with it. It fact, this should never happen.
    return false if report.project.present? && report.project != @project

    # If report does not belong to a project, it is ok to look for the
    # permission in any project. Otherwise, the user should have the permission
    # in this project.
    if report.project.present?
      options = {}
    else
      options = { global: true }
    end

    case action
    when :create
      user.allowed_to?(:save_cost_reports, @project, options) or
        user.allowed_to?(:save_private_cost_reports, @project, options)

    when :save, :destroy, :rename
      if report.is_public?
        user.allowed_to?(:save_cost_reports, @project, options)
      else
        user.allowed_to?(:save_cost_reports, @project, options) or
          user.allowed_to?(:save_private_cost_reports, @project, options)
      end

    when :save_as_public
      user.allowed_to?(:save_cost_reports, @project, options)

    else
      false
    end
  end

  def public_queries
    if @project
      CostQuery.where(['is_public = ? AND (project_id IS NULL OR project_id = ?)', true, @project])
               .order('name ASC')
    else
      CostQuery.where(['is_public = ? AND project_id IS NULL', true])
               .order('name ASC')
    end
  end

  def private_queries
    if @project
      CostQuery.where(['user_id = ? AND is_public = ? AND (project_id IS NULL OR project_id = ?)',
                       current_user,
                       false,
                       @project])
               .order('name ASC')
    else
      CostQuery.where(['user_id = ? AND is_public = ? AND project_id IS NULL', current_user, false])
               .order('name ASC')
    end
  end

  def display_report_list
    report_type = params[:report_type] || :public
    render partial: 'report_list', locals: { report_type: report_type }, layout: !request.xhr?
  end

  private

  def find_optional_user
    @current_user = User.current || User.anonymous
  end

  def default_breadcrumb
    l(:cost_reports_title)
  end
end

class LeaveRequestsController < ApiController
  before_action :authenticate_hr, only: %i[index approve_request reject_request]
  before_action :authenticate_employee, only: %i[show create destroy]

  def index
    leave_requests = LeaveRequest.where(status: 'pending')
    if leave_requests.present?
      render json: leave_requests, status: :ok
    else
      render json: { message: 'There is no leave requests' }, status: :unprocessable_entity
    end
  end

  def show
    render json: @current_user.leave_requests, status: :ok
  end

  def create
    last_request = @current_user.leave_requests.last
    raise unless last_request.nil? || last_request.status == 'approved' || last_request.status == 'rejected'

    leave_request = @current_user.leave_requests.new(leave_params)
    dif = leave_request.end_date - leave_request.start_date
    raise if @current_user.balance <= dif.to_i + 1

    leave_request.days = dif.to_i + 1
    @current_user.balance = @current_user.balance - leave_request.days
    if leave_request.save && @current_user.save
      render json: leave_request, status: :created
    else
      render json: leave_request.errors.full_messages, status: :unprocessable_entity
    end
  rescue StandardError
    render json: { message: 'Insufficient balance or last request is pending' }, status: :unprocessable_entity
  end

  def destroy
    byebug
    last_request = @current_user.leave_requests.last
    raise if last_request.nil? || last_request.status != 'pending'

    @current_user.update(balance: @current_user.balance + last_request.days)
    last_request.destroy!
    render json: { message: 'Leave Request Deleted !' }, status: :ok
  rescue StandardError
    render json: { error: 'Theirs is nothing to Deleted' }, status: :unprocessable_entity
  end

  def approve_request
    leave_request = LeaveRequest.find_by(id: params[:id])
    raise if leave_request.status != 'pending'

    leave_request.status = 'approved'
    leave_request.save
    render json: { message: "Emp id:#{leave_request.employee_id} leave request is approved " }, status: :ok
  rescue StandardError
    render json: { message: 'Not Found' }, status: :unprocessable_entity
  end

  def reject_request
    leave_request = LeaveRequest.find_by(id: params[:id])
    raise if leave_request.status != 'pending'

    current_user = Employee.find_by(id: leave_request.employee_id)
    current_user.update(balance: current_user.balance + leave_request.days)
    leave_request.status = 'rejected'
    leave_request.save
    render json: { message: "Emp id: #{leave_request.employee_id} leave request is rejected " }, status: :ok
  rescue StandardError
    render json: { error: 'Not Found' }, status: :unprocessable_entity
  end

  private

  def leave_params
    params.permit(:start_date, :end_date, :leave_type, :reason, :days, :status)
  end
end

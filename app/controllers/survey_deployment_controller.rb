
class SurveyDeploymentController < ApplicationController

  def action_allowed?
    ['Instructor',
     'Teaching Assistant',
     'Administrator','demo_instructor'].include? current_role_name
  end

  def new
    @surveys=Questionnaire.where(type: 'CourseEvaluationQuestionnaire').map{|u| [u.name, u.id] }
    @course = Course.where(instructor_id: session[:user].id).map{|u| [u.name, u.id] }
    @total_students = CourseParticipant.where(parent_id: @course[0][1]).count
  end

  def create
    survey_deployment=params[:survey_deployment]

    @survey_deployment=SurveyDeployment.new(survey_deployment)
    if(params[:random_subset]["value"]=="1")
      @survey_deployment.num_of_students=User.where(role_id: Role.student.id).length * rand
    end

    if(@survey_deployment.save)
      add_participants(@survey_deployment.num_of_students,@survey_deployment.id)
      redirect_to :action=>'list'
    else
      @surveys=Questionnaire.where(type: 'CourseEvaluationQuestionnaire').map{|u| [u.name, u.id] }
      @course = Course.where(instructor_id: session[:user].id).map{|u| [u.name, u.id] }
      @total_students = CourseParticipant.where(parent_id: @course[0][1]).count
      render(:action=>'new')
    end
  end

  def list
    @survey_deployments=SurveyDeployment.all
    @surveys={}
    @survey_deployments.each do |sd|
      @surveys[sd.id]=Questionnaire.find(sd.course_evaluation_id).name
    end
  end



  def delete
    SurveyDeployment.find(params[:id]).destroy
    SurveyParticipant.where(survey_deployment_id: params[:id]).each do |sp|
      sp.destroy
    end
    SurveyResponse.where(survey_deployment_id: params[:id]).each do |sr|
      sr.destroy
    end
    redirect_to :action=>'list'
  end

  def add_participants(num_of_participants,survey_deployment_id) #Add participants
    users=User.where(role_id: Role.student.id)
    users_rand=users.sort_by{rand} #randomize user list
    num_of_participants.times do |i|
      survey_participant=SurveyParticipant.new
      survey_participant.user_id=users_rand[i].id
      survey_participant.survey_deployment_id=survey_deployment_id
      survey_participant.save
    end

  end

  def reminder_thread

    #Check status of  reminder thread
    @reminder_thread_status="Running"
    unless MiddleMan.get_worker(session[:reminder_key])
      @reminder_thread_status="Not Running"
    end

  end

  def toggle_reminder_thread
    #Create reminder thread using BackgroundRb or kill it if its already running
    unless MiddleMan.get_worker(session[:reminder_key])
      session[:reminder_key]=MiddleMan.new_worker :class=>:reminder_worker, :args=>{:num_reminders=>3} # 3 reminders for now
    else
      MiddleMan.delete_worker(session[:reminder_key])
      session[:reminder_key]=nil
    end
    redirect_to :action=>'reminder_thread'
  end



end

class ProposalsController < ApplicationController
  before_action :set_proposal, only: %i[show edit update destroy]

  def index
    @proposals = current_user.proposals.includes(:latest_clarity_check).order(created_at: :desc)
  end

  def show
    @clarity_checks = @proposal.clarity_checks.order(created_at: :desc)
  end

  def new
    @proposal = current_user.proposals.build(decider: "whole_community")
  end

  def create
    @proposal = current_user.proposals.build(proposal_params)
    if @proposal.save
      redirect_to @proposal
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @proposal.update(proposal_params)
      redirect_to @proposal
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @proposal.destroy
    redirect_to proposals_path
  end

  private

  def set_proposal
    @proposal = current_user.proposals.find(params[:id])
  end

  def proposal_params
    params.require(:proposal).permit(:title, :body, :problem, :decider, :deadline_or_cost)
  end
end

class DocumentsController < ApplicationController
  before_action :authenticate_user!
  before_filter :find_documentable, except: :destroy
  before_filter :prepare_new_document, only: :new
  before_filter :prepare_document_for_creation, only: :create

  load_and_authorize_resource :except => [:upload]
  skip_authorization_check :only => [:upload]

  def new
  end

  def create
    recover_attachment_from_cache
    if @document.save
      flash[:notice] = t "documents.actions.create.notice"
      redirect_to params[:from]
    else
      flash[:alert] = t "documents.actions.create.alert"
      render :new
    end
  end

  def destroy
    if @document.destroy
      flash[:notice] = t "documents.actions.destroy.notice"
    else
      flash[:alert] = t "documents.actions.destroy.alert"
    end
    redirect_to params[:from]
  end

  def upload
    attachment = params[:document][:attachment]
    document = Document.new(documentable: @documentable, attachment: attachment.tempfile, title: "faketitle", user: current_user )
    # We only are intested in attachment validators. We set some fake data to get attachment errors only
    document.valid?
    if document.errors[:attachment].empty?
      # Move image from tmp to cache
      msg = { status: 200, attachment: attachment.tempfile.path }
    else
      attachment.tempfile.delete
      msg = { status: 422, msg: document.errors[:attachment].join(', ') }
    end
    render :json => msg
  end

  private

  def find_documentable
    @documentable = params[:documentable_type].constantize.find_or_initialize_by(id: params[:documentable_id])
  end

  def prepare_new_document
    @document = Document.new(documentable: @documentable, user_id: @documentable.author_id)
  end

  def prepare_document_for_creation
    @document = Document.new(document_params)
    @document.documentable = @documentable
    @document.user = current_user
  end

  def document_params
    params.require(:document).permit(:title, :documentable_type, :documentable_id,
                                     :attachment, :cached_attachment)
  end

  def recover_attachment_from_cache
    if @document.attachment.blank? && @document.cached_attachment.present?
      @document.attachment = File.open(@document.cached_attachment)
    end
  end

end

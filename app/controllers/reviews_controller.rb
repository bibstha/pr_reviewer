class ReviewsController < ApplicationController
  def new
    @review = Review.new
  end

  def create
    owner, repo, number = parse_pr_url(params[:pr_url].to_s)

    unless owner && repo && number
      @review = Review.new
      flash.now[:alert] = "Invalid PR URL. Use formats like https://github.com/owner/repo/pull/123, owner/repo#123, or owner/repo/pull/123"
      render :new, status: :unprocessable_content
      return
    end

    token = params[:github_token].to_s.strip

    if token.blank?
      @review = Review.new
      flash.now[:alert] = "GitHub token is required"
      render :new, status: :unprocessable_content
      return
    end

    @review = Review.new(
      repo_owner: owner,
      repo_name: repo,
      pr_number: number.to_i,
      github_token: token,
      status: "fetching"
    )

    if @review.save
      FetchPrDataJob.perform_later(@review.id)
      redirect_to review_path(@review)
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @review = Review.find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  PR_URL_PATTERNS = [
    %r{github\.com/([^/]+)/([^/]+)/pull/(\d+)},
    %r{^([^/\s]+)/([^/\s]+)#(\d+)$},
    %r{^([^/\s]+)/([^/\s]+)/pull/(\d+)$}
  ].freeze

  def parse_pr_url(url)
    url = url.strip
    PR_URL_PATTERNS.each do |pattern|
      if (match = url.match(pattern))
        return [match[1], match[2], match[3]]
      end
    end
    [nil, nil, nil]
  end
end

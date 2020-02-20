class Admin2::MembershipPresenter
  include Collator

  private

  attr_reader :service, :params

  public

  delegate :memberships, :community, to: :service, prefix: false, allow_nil: false

  def initialize(service:, params:)
    @service = service
    @params = params
  end

  FILTER_STATUSES = %w[admin banned posting_allowed accepted unconfirmed pending]

  def sorted_statuses
    FILTER_STATUSES.map {|status|
      [status, "#{I18n.t("admin.communities.manage_members.status_filter.#{status}")} (#{count_by_status(status)})" , status_checked?(status)]
    }.sort_by{ |_status, translation, _checked| collator.get_sort_key(translation) }
  end

  def count_by_status(status)
    case status
    when 'admin'
      community.community_memberships.admin.count
    when CommunityMembership::BANNED
      community.community_memberships.banned.count
    when 'posting_allowed'
      community.community_memberships.posting_allowed.count
    when CommunityMembership::ACCEPTED
      community.community_memberships.accepted.count
    when 'unconfirmed'
      community.community_memberships.pending_email_confirmation.count
    when 'pending'
      community.community_memberships.pending_consent.count
    else
      0
    end
  end

  def status_checked?(status)
    params[:status].present? && params[:status].include?(status)
  end

  def person_name(person)
    display_name = person.display_name.present? ? " (#{person.display_name})" : ''
    "#{person.given_name} #{person.family_name}#{display_name}"
  end

  def can_post_listing(membership)
    ready = !(membership.pending_consent? || membership.pending_email_confirmation?)
    if require_verification_to_post_listings
      membership.can_post_listings && ready
    else
      ready
    end
  end

  def require_verification_to_post_listings
    community.require_verification_to_post_listings
  end

  def has_membership_unfinished_transactions(membership)
    Transaction.unfinished_for_person(membership.person).any?
  end

  def can_delete(membership)
    can_delete_pending(membership) || can_delete_accepted(membership)
  end

  def can_delete_accepted(membership)
    membership.banned? && !has_membership_unfinished_transactions(membership)
  end

  def can_delete_pending(membership)
    membership.pending_consent? || membership.pending_email_confirmation?
  end

  def delete_member_title(membership)
    if can_delete_pending(membership)
      nil
    else
      title = has_membership_unfinished_transactions(membership) ? I18n.t('admin.communities.manage_members.have_ongoing_transactions') : nil
      title ||= membership.banned? ? nil : I18n.t('admin.communities.manage_members.only_delete_disabled')
    end
  end
end
